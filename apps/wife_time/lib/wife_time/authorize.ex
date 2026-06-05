defmodule WifeTime.Authorize do
  @roles      WifeTime.Users.Roles
  @user       WifeTime.Users.User
  @user_role  WifeTime.Users.UserRole
  @user_roles WifeTime.UserRoles
  alias HfgPortal.Helpers.Page

  @pages [
    %Page{id: "home",  name: "Home",  module: HfgPortalWeb.WifeTime.Home.HomeLive},
    %Page{id: "users", name: "Users", module: HfgPortalWeb.WifeTime.Users.UsersLive},
  ]

  use HfgPortal.Helpers.DefaultAuthorize,
    roles:      @roles,
    user:       @user,
    user_role:  @user_role,
    user_roles: @user_roles,
    pages:      @pages
end
