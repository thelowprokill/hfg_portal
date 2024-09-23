defmodule HullFamilyGamesWeb.CustomerSessionControllerTest do
  use HullFamilyGamesWeb.ConnCase

  import HullFamilyGames.AccountsFixtures

  setup do
    %{customer: customer_fixture()}
  end

  describe "GET /customers/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, ~p"/customers/log_in")
      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ ~p"/customers/register"
      assert response =~ "Forgot your password?"
    end

    test "redirects if already logged in", %{conn: conn, customer: customer} do
      conn = conn |> log_in_customer(customer) |> get(~p"/customers/log_in")
      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /customers/log_in" do
    test "logs the customer in", %{conn: conn, customer: customer} do
      conn =
        post(conn, ~p"/customers/log_in", %{
          "customer" => %{"email" => customer.email, "password" => valid_customer_password()}
        })

      assert get_session(conn, :customer_token)
      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, ~p"/")
      response = html_response(conn, 200)
      assert response =~ customer.email
      assert response =~ ~p"/customers/settings"
      assert response =~ ~p"/customers/log_out"
    end

    test "logs the customer in with remember me", %{conn: conn, customer: customer} do
      conn =
        post(conn, ~p"/customers/log_in", %{
          "customer" => %{
            "email" => customer.email,
            "password" => valid_customer_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_hull_family_games_web_customer_remember_me"]
      assert redirected_to(conn) == ~p"/"
    end

    test "logs the customer in with return to", %{conn: conn, customer: customer} do
      conn =
        conn
        |> init_test_session(customer_return_to: "/foo/bar")
        |> post(~p"/customers/log_in", %{
          "customer" => %{
            "email" => customer.email,
            "password" => valid_customer_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Welcome back!"
    end

    test "emits error message with invalid credentials", %{conn: conn, customer: customer} do
      conn =
        post(conn, ~p"/customers/log_in", %{
          "customer" => %{"email" => customer.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "Log in"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /customers/log_out" do
    test "logs the customer out", %{conn: conn, customer: customer} do
      conn = conn |> log_in_customer(customer) |> delete(~p"/customers/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :customer_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the customer is not logged in", %{conn: conn} do
      conn = delete(conn, ~p"/customers/log_out")
      assert redirected_to(conn) == ~p"/"
      refute get_session(conn, :customer_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Logged out successfully"
    end
  end
end
