defmodule HullFamilyGamesWeb.CustomerConfirmationControllerTest do
  use HullFamilyGamesWeb.ConnCase

  alias HullFamilyGames.Accounts
  alias HullFamilyGames.Repo
  import HullFamilyGames.AccountsFixtures

  setup do
    %{customer: customer_fixture()}
  end

  describe "GET /customers/confirm" do
    test "renders the resend confirmation page", %{conn: conn} do
      conn = get(conn, ~p"/customers/confirm")
      response = html_response(conn, 200)
      assert response =~ "Resend confirmation instructions"
    end
  end

  describe "POST /customers/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, customer: customer} do
      conn =
        post(conn, ~p"/customers/confirm", %{
          "customer" => %{"email" => customer.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Accounts.CustomerToken, customer_id: customer.id).context == "confirm"
    end

    test "does not send confirmation token if Customer is confirmed", %{conn: conn, customer: customer} do
      Repo.update!(Accounts.Customer.confirm_changeset(customer))

      conn =
        post(conn, ~p"/customers/confirm", %{
          "customer" => %{"email" => customer.email}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Accounts.CustomerToken, customer_id: customer.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/customers/confirm", %{
          "customer" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Accounts.CustomerToken) == []
    end
  end

  describe "GET /customers/confirm/:token" do
    test "renders the confirmation page", %{conn: conn} do
      token_path = ~p"/customers/confirm/some-token"
      conn = get(conn, token_path)
      response = html_response(conn, 200)
      assert response =~ "Confirm account"

      assert response =~ "action=\"#{token_path}\""
    end
  end

  describe "POST /customers/confirm/:token" do
    test "confirms the given token once", %{conn: conn, customer: customer} do
      token =
        extract_customer_token(fn url ->
          Accounts.deliver_customer_confirmation_instructions(customer, url)
        end)

      conn = post(conn, ~p"/customers/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "Customer confirmed successfully"

      assert Accounts.get_customer!(customer.id).confirmed_at
      refute get_session(conn, :customer_token)
      assert Repo.all(Accounts.CustomerToken) == []

      # When not logged in
      conn = post(conn, ~p"/customers/confirm/#{token}")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Customer confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_customer(customer)
        |> post(~p"/customers/confirm/#{token}")

      assert redirected_to(conn) == ~p"/"
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, customer: customer} do
      conn = post(conn, ~p"/customers/confirm/oops")
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "Customer confirmation link is invalid or it has expired"

      refute Accounts.get_customer!(customer.id).confirmed_at
    end
  end
end
