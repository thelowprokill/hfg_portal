defmodule HullFamilyGamesWeb.ApiUserConfirmationControllerTest do
  use HullFamilyGamesWeb.ConnCase

  alias HullFamilyGames.Accounts
  alias HullFamilyGames.Repo
  import HullFamilyGames.AccountsFixtures

  setup do
    %{api_user: api_user_fixture()}
  end

  describe "GET /api_users/confirm" do
    test "renders the resend confirmation page", %{conn: conn} do
      conn = get(conn, ~p"/api_users/confirm")
      response = html_response(conn, 200)
      assert response =~ "Resend confirmation instructions"
    end
  end

  describe "POST /api_users/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, api_user: api_user} do
      conn =
        post(conn, ~p"/api_users/confirm", %{
          "api_user" => %{"email" => api_user.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.ApiUserToken, api_user_id: api_user.id).context == "confirm"
    end

    test "does not send confirmation token if Api user is confirmed", %{conn: conn, api_user: api_user} do
      Repo.update!(Accounts.ApiUser.confirm_changeset(api_user))

      conn =
        post(conn, ~p"/api_users/confirm", %{
          "api_user" => %{"email" => api_user.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Accounts.ApiUserToken, api_user_id: api_user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/api_users/confirm", %{
          "api_user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.ApiUserToken) == []
    end
  end

  describe "GET /api_users/confirm/:token" do
    test "renders the confirmation page", %{conn: conn} do
      token_path = ~p"/api_users/confirm/some-token"
      conn = get(conn, token_path)
      response = html_response(conn, 200)
      assert response =~ "Confirm account"

      assert response =~ "action=\"#{token_path}\""
    end
  end

  describe "POST /api_users/confirm/:token" do
    test "confirms the given token once", %{conn: conn, api_user: api_user} do
      token =
        extract_api_user_token(fn url ->
          Accounts.deliver_api_user_confirmation_instructions(api_user, url)
        end)

      conn = post(conn, ~p"/api_users/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Api user confirmed successfully"

      assert Accounts.get_api_user!(api_user.id).confirmed_at
      refute get_session(conn, :api_user_token)
      assert Repo.all(Accounts.ApiUserToken) == []

      # When not logged in
      conn = post(conn, ~p"/api_users/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Api user confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_api_user(api_user)
        |> post(~p"/api_users/confirm/#{token}")

      assert redirected_to(conn) == ~p"/"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, api_user: api_user} do
      conn = post(conn, ~p"/api_users/confirm/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Api user confirmation link is invalid or it has expired"

      refute Accounts.get_api_user!(api_user.id).confirmed_at
    end
  end
end
