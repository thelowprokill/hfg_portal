defmodule BnwPortalWeb.CustomerSettingsControllerTest do
  use BnwPortalWeb.ConnCase

  alias BnwPortal.Accounts
  import BnwPortal.AccountsFixtures

  setup :register_and_log_in_customer

  describe "GET /customers/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, ~p"/customers/settings")
      response = html_response(conn, 200)
      assert response =~ "Settings"
    end

    test "redirects if customer is not logged in" do
      conn = build_conn()
      conn = get(conn, ~p"/customers/settings")
      assert redirected_to(conn) == ~p"/customers/log_in"
    end
  end

  describe "PUT /customers/settings (change password form)" do
    test "updates the customer password and resets tokens", %{conn: conn, customer: customer} do
      new_password_conn =
        put(conn, ~p"/customers/settings", %{
          "action" => "update_password",
          "current_password" => valid_customer_password(),
          "customer" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == ~p"/customers/settings"

      assert get_session(new_password_conn, :customer_token) != get_session(conn, :customer_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_customer_by_email_and_password(customer.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, ~p"/customers/settings", %{
          "action" => "update_password",
          "current_password" => "invalid",
          "customer" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "Settings"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
      assert response =~ "is not valid"

      assert get_session(old_password_conn, :customer_token) == get_session(conn, :customer_token)
    end
  end

  describe "PUT /customers/settings (change email form)" do
    @tag :capture_log
    test "updates the customer email", %{conn: conn, customer: customer} do
      conn =
        put(conn, ~p"/customers/settings", %{
          "action" => "update_email",
          "current_password" => valid_customer_password(),
          "customer" => %{"email" => unique_customer_email()}
        })

      assert redirected_to(conn) == ~p"/customers/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "A link to confirm your email"

      assert Accounts.get_customer_by_email(customer.email)
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        put(conn, ~p"/customers/settings", %{
          "action" => "update_email",
          "current_password" => "invalid",
          "customer" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "Settings"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "is not valid"
    end
  end

  describe "GET /customers/settings/confirm_email/:token" do
    setup %{customer: customer} do
      email = unique_customer_email()

      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_update_email_instructions(%{customer | email: email}, customer.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the customer email once", %{conn: conn, customer: customer, token: token, email: email} do
      conn = get(conn, ~p"/customers/settings/confirm_email/#{token}")
      assert redirected_to(conn) == ~p"/customers/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Email changed successfully"

      refute Accounts.get_customer_by_email(customer.email)
      assert Accounts.get_customer_by_email(email)

      conn = get(conn, ~p"/customers/settings/confirm_email/#{token}")

      assert redirected_to(conn) == ~p"/customers/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, customer: customer} do
      conn = get(conn, ~p"/customers/settings/confirm_email/oops")
      assert redirected_to(conn) == ~p"/customers/settings"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Email change link is invalid or it has expired"

      assert Accounts.get_customer_by_email(customer.email)
    end

    test "redirects if customer is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, ~p"/customers/settings/confirm_email/#{token}")
      assert redirected_to(conn) == ~p"/customers/log_in"
    end
  end
end
