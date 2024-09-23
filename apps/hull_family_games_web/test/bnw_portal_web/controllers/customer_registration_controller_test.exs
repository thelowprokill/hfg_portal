defmodule HullFamilyGamesWeb.CustomerRegistrationControllerTest do
  use HullFamilyGamesWeb.ConnCase

  import HullFamilyGames.AccountsFixtures

  describe "GET /customers/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/customers/register")
      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ ~p"/customers/log_in"
      assert response =~ ~p"/customers/register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_customer(customer_fixture()) |> get(~p"/customers/register")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /customers/register" do
    @tag :capture_log
    test "creates account and logs the customer in", %{conn: conn} do
      email = unique_customer_email()

      conn =
        post(conn, ~p"/customers/register", %{
          "customer" => valid_customer_attributes(email: email)
        })

      assert get_session(conn, :customer_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ ~p"/customers/settings"
      assert response =~ ~p"/customers/log_out"
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/customers/register", %{
          "customer" => %{"email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end
  end
end
