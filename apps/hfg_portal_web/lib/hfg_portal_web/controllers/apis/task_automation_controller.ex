defmodule HfgPortalWeb.Apis.TaskAutomationControllerApiController do
  use HfgPortalWeb, :controller

  alias TaskAutomationController.{
    QueuedItems
  }

  # credentials come from TAC_API_USERNAME / TAC_API_PASSWORD; unset means nobody gets in
  def update(conn, params) do
    if valid_credentials?(params) do
      QueuedItems.update()
      send_resp(conn, :no_content, "")
    else
      send_resp(conn, :not_found, "")
    end
  end

  defp valid_credentials?(%{"username" => username, "password" => password})
       when is_binary(username) and is_binary(password) do
    with expected_user when is_binary(expected_user) and expected_user != "" <- System.get_env("TAC_API_USERNAME"),
         expected_pass when is_binary(expected_pass) and expected_pass != "" <- System.get_env("TAC_API_PASSWORD") do
      # evaluate both so a wrong username takes as long as a wrong password
      user_ok = Plug.Crypto.secure_compare(username, expected_user)
      pass_ok = Plug.Crypto.secure_compare(password, expected_pass)
      user_ok and pass_ok
    else
      _ -> false
    end
  end

  defp valid_credentials?(_), do: false
end
