defmodule HullFamilyGamesWeb.CustomerSessionController do
  use HullFamilyGamesWeb, :controller

  alias HullFamilyGames.Accounts
  alias HullFamilyGamesWeb.CustomerAuth

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  def create(conn, %{"customer" => customer_params}) do
    %{"email" => email, "password" => password} = customer_params

    if customer = Accounts.get_customer_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> CustomerAuth.log_in_customer(customer, customer_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, :new, error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> CustomerAuth.log_out_customer()
  end
end
