defmodule HfgPortalWeb.ApiUserSessionController do
  use HfgPortalWeb, :controller

  #alias HfgPortal.Accounts
  #alias HfgPortalWeb.ApiUserAuth

  def new(conn, _params) do
    render(conn, :new, error_message: nil)
  end

  #ref create(conn, %{"api_user" => api_user_params}) do
  #  %{"email" => email, "password" => password} = api_user_params

  #  if api_user = Accounts.get_api_user_by_email_and_password(email, password) do
  #    conn
  #    |> put_flash(:info, "Welcome back!")
  #    |> ApiUserAuth.log_in_api_user(api_user, api_user_params)
  #  else
  #    # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
  #    render(conn, :new, error_message: "Invalid email or password")
  #  end
  #end

  #def delete(conn, _params) do
  #  conn
  #  |> put_flash(:info, "Logged out successfully.")
  #  |> ApiUserAuth.log_out_api_user()
  #end
end
