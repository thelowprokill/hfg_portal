defmodule HfgPortalWeb.Apis.Budget.AuthController do
  def authorized?(conn, %{role: required_role}) do
    user = conn.assigns.current_api_user

    Budget.UserRoles.get(user.id, :user)
    |> case do
      nil       -> false
      user_role -> Map.get(Budget.Users.Roles.get(user_role.role), required_role, false)
    end
  end
end
