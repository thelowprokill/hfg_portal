defmodule BnwPortalWeb.CustomerResetPasswordControllerTest do
  use BnwPortalWeb.ConnCase

  alias BnwPortal.Accounts
  alias BnwPortal.Repo
  import BnwPortal.AccountsFixtures

  setup do
    %{customer: customer_fixture()}
  end

  describe "GET /customers/reset_password" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, ~p"/customers/reset_password")
      response = html_response(conn, 200)
      assert response =~ "Forgot your password?"
    end
  end

  describe "POST /customers/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, customer: customer} do
      conn =
        post(conn, ~p"/customers/reset_password", %{
          "customer" => %{"email" => customer.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.CustomerToken, customer_id: customer.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/customers/reset_password", %{
          "customer" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.CustomerToken) == []
    end
  end

  describe "GET /customers/reset_password/:token" do
    setup %{customer: customer} do
      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_reset_password_instructions(customer, url)
        end)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, ~p"/customers/reset_password/#{token}")
      assert html_response(conn, 200) =~ "Reset password"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, ~p"/customers/reset_password/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Reset password link is invalid or it has expired"
    end
  end

  describe "PUT /customers/reset_password/:token" do
    setup %{customer: customer} do
      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_reset_password_instructions(customer, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, customer: customer, token: token} do
      conn =
        put(conn, ~p"/customers/reset_password/#{token}", %{
          "customer" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == ~p"/customers/log_in"
      refute get_session(conn, :customer_token)

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Password reset successfully"

      assert Accounts.get_customer_by_email_and_password(customer.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, ~p"/customers/reset_password/#{token}", %{
          "customer" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert html_response(conn, 200) =~ "something went wrong"
    end

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, ~p"/customers/reset_password/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Reset password link is invalid or it has expired"
    end
  end
end
