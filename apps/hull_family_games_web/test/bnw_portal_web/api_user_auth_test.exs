defmodule HullFamilyGamesWeb.ApiUserAuthTest do
  use HullFamilyGamesWeb.ConnCase

  alias Phoenix.LiveView
  alias HullFamilyGames.Accounts
  alias HullFamilyGamesWeb.ApiUserAuth
  import HullFamilyGames.AccountsFixtures

  @remember_me_cookie "_hull_family_games_web_api_user_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, HullFamilyGamesWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{api_user: api_user_fixture(), conn: conn}
  end

  describe "log_in_api_user/3" do
    test "stores the api_user token in the session", %{conn: conn, api_user: api_user} do
      conn = ApiUserAuth.log_in_api_user(conn, api_user)
      assert token = get_session(conn, :api_user_token)
      assert get_session(conn, :live_socket_id) == "api_users_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == ~p"/"
      assert Accounts.get_api_user_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, api_user: api_user} do
      conn = conn |> put_session(:to_be_removed, "value") |> ApiUserAuth.log_in_api_user(api_user)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, api_user: api_user} do
      conn = conn |> put_session(:api_user_return_to, "/hello") |> ApiUserAuth.log_in_api_user(api_user)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, api_user: api_user} do
      conn = conn |> fetch_cookies() |> ApiUserAuth.log_in_api_user(api_user, %{"remember_me" => "true"})
      assert get_session(conn, :api_user_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :api_user_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_api_user/1" do
    test "erases session and cookies", %{conn: conn, api_user: api_user} do
      api_user_token = Accounts.generate_api_user_session_token(api_user)

      conn =
        conn
        |> put_session(:api_user_token, api_user_token)
        |> put_req_cookie(@remember_me_cookie, api_user_token)
        |> fetch_cookies()
        |> ApiUserAuth.log_out_api_user()

      refute get_session(conn, :api_user_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
      refute Accounts.get_api_user_by_session_token(api_user_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "api_users_sessions:abcdef-token"
      HullFamilyGamesWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> ApiUserAuth.log_out_api_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if api_user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> ApiUserAuth.log_out_api_user()
      refute get_session(conn, :api_user_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "fetch_current_api_user/2" do
    test "authenticates api_user from session", %{conn: conn, api_user: api_user} do
      api_user_token = Accounts.generate_api_user_session_token(api_user)
      conn = conn |> put_session(:api_user_token, api_user_token) |> ApiUserAuth.fetch_current_api_user([])
      assert conn.assigns.current_api_user.id == api_user.id
    end

    test "authenticates api_user from cookies", %{conn: conn, api_user: api_user} do
      logged_in_conn =
        conn |> fetch_cookies() |> ApiUserAuth.log_in_api_user(api_user, %{"remember_me" => "true"})

      api_user_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> ApiUserAuth.fetch_current_api_user([])

      assert conn.assigns.current_api_user.id == api_user.id
      assert get_session(conn, :api_user_token) == api_user_token

      assert get_session(conn, :live_socket_id) ==
               "api_users_sessions:#{Base.url_encode64(api_user_token)}"
    end

    test "does not authenticate if data is missing", %{conn: conn, api_user: api_user} do
      _ = Accounts.generate_api_user_session_token(api_user)
      conn = ApiUserAuth.fetch_current_api_user(conn, [])
      refute get_session(conn, :api_user_token)
      refute conn.assigns.current_api_user
    end
  end

  describe "on_mount: mount_current_api_user" do
    test "assigns current_api_user based on a valid api_user_token", %{conn: conn, api_user: api_user} do
      api_user_token = Accounts.generate_api_user_session_token(api_user)
      session = conn |> put_session(:api_user_token, api_user_token) |> get_session()

      {:cont, updated_socket} =
        ApiUserAuth.on_mount(:mount_current_api_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_api_user.id == api_user.id
    end

    test "assigns nil to current_api_user assign if there isn't a valid api_user_token", %{conn: conn} do
      api_user_token = "invalid_token"
      session = conn |> put_session(:api_user_token, api_user_token) |> get_session()

      {:cont, updated_socket} =
        ApiUserAuth.on_mount(:mount_current_api_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_api_user == nil
    end

    test "assigns nil to current_api_user assign if there isn't a api_user_token", %{conn: conn} do
      session = conn |> get_session()

      {:cont, updated_socket} =
        ApiUserAuth.on_mount(:mount_current_api_user, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_api_user == nil
    end
  end

  describe "on_mount: ensure_authenticated" do
    test "authenticates current_api_user based on a valid api_user_token", %{conn: conn, api_user: api_user} do
      api_user_token = Accounts.generate_api_user_session_token(api_user)
      session = conn |> put_session(:api_user_token, api_user_token) |> get_session()

      {:cont, updated_socket} =
        ApiUserAuth.on_mount(:ensure_authenticated, %{}, session, %LiveView.Socket{})

      assert updated_socket.assigns.current_api_user.id == api_user.id
    end

    test "redirects to login page if there isn't a valid api_user_token", %{conn: conn} do
      api_user_token = "invalid_token"
      session = conn |> put_session(:api_user_token, api_user_token) |> get_session()

      socket = %LiveView.Socket{
        endpoint: HullFamilyGamesWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = ApiUserAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_api_user == nil
    end

    test "redirects to login page if there isn't a api_user_token", %{conn: conn} do
      session = conn |> get_session()

      socket = %LiveView.Socket{
        endpoint: HullFamilyGamesWeb.Endpoint,
        assigns: %{__changed__: %{}, flash: %{}}
      }

      {:halt, updated_socket} = ApiUserAuth.on_mount(:ensure_authenticated, %{}, session, socket)
      assert updated_socket.assigns.current_api_user == nil
    end
  end

  describe "on_mount: :redirect_if_api_user_is_authenticated" do
    test "redirects if there is an authenticated  api_user ", %{conn: conn, api_user: api_user} do
      api_user_token = Accounts.generate_api_user_session_token(api_user)
      session = conn |> put_session(:api_user_token, api_user_token) |> get_session()

      assert {:halt, _updated_socket} =
               ApiUserAuth.on_mount(
                 :redirect_if_api_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end

    test "doesn't redirect if there is no authenticated api_user", %{conn: conn} do
      session = conn |> get_session()

      assert {:cont, _updated_socket} =
               ApiUserAuth.on_mount(
                 :redirect_if_api_user_is_authenticated,
                 %{},
                 session,
                 %LiveView.Socket{}
               )
    end
  end

  describe "redirect_if_api_user_is_authenticated/2" do
    test "redirects if api_user is authenticated", %{conn: conn, api_user: api_user} do
      conn = conn |> assign(:current_api_user, api_user) |> ApiUserAuth.redirect_if_api_user_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"
    end

    test "does not redirect if api_user is not authenticated", %{conn: conn} do
      conn = ApiUserAuth.redirect_if_api_user_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_api_user/2" do
    test "redirects if api_user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> ApiUserAuth.require_authenticated_api_user([])
      assert conn.halted

      assert redirected_to(conn) == ~p"/api_users/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> ApiUserAuth.require_authenticated_api_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :api_user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> ApiUserAuth.require_authenticated_api_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :api_user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> ApiUserAuth.require_authenticated_api_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :api_user_return_to)
    end

    test "does not redirect if api_user is authenticated", %{conn: conn, api_user: api_user} do
      conn = conn |> assign(:current_api_user, api_user) |> ApiUserAuth.require_authenticated_api_user([])
      refute conn.halted
      refute conn.status
    end
  end
end
