defmodule BnwPortalWeb.ApiUserSessionControllerTest do
  use BnwPortalWeb.ConnCase

  import BnwPortal.AccountsFixtures

  setup do
    %{api_user: api_user_fixture()}
  end

  describe "GET /api_users/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, ~p"/api_users/log_in")
      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ ~p"/api_users/register"
      assert response =~ "Forgot your password?"
    end

    test "redirects if already logged in", %{conn: conn, api_user: api_user} do
      conn = conn |> log_in_api_user(api_user) |> get(~p"/api_users/log_in")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /api_users/log_in" do
    test "logs the api_user in", %{conn: conn, api_user: api_user} do
      conn =
        post(conn, ~p"/api_users/log_in", %{
          "api_user" => %{"email" => api_user.email, "password" => valid_api_user_password()}
        })

      assert get_session(conn, :api_user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ api_user.email
      assert response =~ ~p"/api_users/settings"
      assert response =~ ~p"/api_users/log_out"
    end

    test "logs the api_user in with remember me", %{conn: conn, api_user: api_user} do
      conn =
        post(conn, ~p"/api_users/log_in", %{
          "api_user" => %{
            "email" => api_user.email,
            "password" => valid_api_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_bnw_portal_web_api_user_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the api_user in with return to", %{conn: conn, api_user: api_user} do
      conn =
        conn
        |> init_test_session(api_user_return_to: "/foo/bar")
        |> post(~p"/api_users/log_in", %{
          "api_user" => %{
            "email" => api_user.email,
            "password" => valid_api_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "emits error message with invalid credentials", %{conn: conn, api_user: api_user} do
      conn =
        post(conn, ~p"/api_users/log_in", %{
          "api_user" => %{"email" => api_user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /api_users/log_out" do
    test "logs the api_user out", %{conn: conn, api_user: api_user} do
      conn = conn |> log_in_api_user(api_user) |> delete(~p"/api_users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :api_user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the api_user is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/api_users/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :api_user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
