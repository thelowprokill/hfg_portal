defmodule HfgPortalWeb.Apis.CarMaintenance.AuthController do
  def authorized?(conn, %{role: required_role}) do
    user = conn.assigns.current_api_user

    CarMaintenance.UserRoles.get(user.id, :user)
    |> case do
      nil       -> false
      user_role -> Map.get(CarMaintenance.Users.Roles.get(user_role.role), required_role, false)
    end
  end
end
