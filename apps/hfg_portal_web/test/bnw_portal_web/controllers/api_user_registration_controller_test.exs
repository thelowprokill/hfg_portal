defmodule HfgPortalWeb.ApiUserRegistrationControllerTest do
  use HfgPortalWeb.ConnCase

  import HfgPortal.AccountsFixtures

  describe "GET /api_users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/api_users/register")
      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ ~p"/api_users/log_in"
      assert response =~ ~p"/api_users/register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_api_user(api_user_fixture()) |> get(~p"/api_users/register")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /api_users/register" do
    @tag :capture_log
    test "creates account and logs the api_user in", %{conn: conn} do
      email = unique_api_user_email()

      conn =
        post(conn, ~p"/api_users/register", %{
          "api_user" => valid_api_user_attributes(email: email)
        })

      assert get_session(conn, :api_user_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ ~p"/api_users/settings"
      assert response =~ ~p"/api_users/log_out"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/api_users/register", %{
          "api_user" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
