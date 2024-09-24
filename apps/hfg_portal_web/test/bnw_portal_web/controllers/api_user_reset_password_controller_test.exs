defmodule HfgPortalWeb.ApiUserResetPasswordControllerTest do
  use HfgPortalWeb.ConnCase

  alias HfgPortal.Accounts
  alias HfgPortal.Repo
  import HfgPortal.AccountsFixtures

  setup do
    %{api_user: api_user_fixture()}
  end

  describe "GET /api_users/reset_password" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, ~p"/api_users/reset_password")
      response = html_response(conn, 200)
      assert response =~ "Forgot your password?"
    end
  end

  describe "POST /api_users/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, api_user: api_user} do
      conn =
        post(conn, ~p"/api_users/reset_password", %{
          "api_user" => %{"email" => api_user.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.ApiUserToken, api_user_id: api_user.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/api_users/reset_password", %{
          "api_user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.ApiUserToken) == []
    end
  end

  describe "GET /api_users/reset_password/:token" do
    setup %{api_user: api_user} do
      token =
        extract_api_user_token(fn url ->
          Accounts.deliver_api_user_reset_password_instructions(api_user, url)
        end)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, ~p"/api_users/reset_password/#{token}")
      assert html_response(conn, 200) =~ "Reset password"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, ~p"/api_users/reset_password/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Reset password link is invalid or it has expired"
    end
  end

  describe "PUT /api_users/reset_password/:token" do
    setup %{api_user: api_user} do
      token =
        extract_api_user_token(fn url ->
          Accounts.deliver_api_user_reset_password_instructions(api_user, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, api_user: api_user, token: token} do
      conn =
        put(conn, ~p"/api_users/reset_password/#{token}", %{
          "api_user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == ~p"/api_users/log_in"
      refute get_session(conn, :api_user_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Password reset successfully"

      assert Accounts.get_api_user_by_email_and_password(api_user.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, ~p"/api_users/reset_password/#{token}", %{
          "api_user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert html_response(conn, 200) =~ "something went wrong"
    end

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, ~p"/api_users/reset_password/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Reset password link is invalid or it has expired"
    end
  end
end
