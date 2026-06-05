defmodule CarMaintenance.Authorize do
  @roles      CarMaintenance.Users.Roles
  @user       CarMaintenance.Users.User
  @user_role  CarMaintenance.Users.UserRole
  @user_roles CarMaintenance.UserRoles
  alias HfgPortal.Helpers.Page
  
  @pages [
    %Page{id: "home",  name: "Home",  module: HfgPortalWeb.CarMaintenance.Home.HomeLive},
    %Page{id: "users", name: "Users", module: HfgPortalWeb.CarMaintenance.Users.UsersLive},
  ]

  use HfgPortal.Helpers.DefaultAuthorize,
    roles:      @roles,
    user:       @user,
    user_role:  @user_role,
    user_roles: @user_roles,
    pages:      @pages
end
