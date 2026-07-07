defmodule Timekeeping.Authorize do
  @roles      Timekeeping.Users.Roles
  @user       Timekeeping.Users.User
  @user_role  Timekeeping.Users.UserRole
  @user_roles Timekeeping.UserRoles
  alias HfgPortal.Helpers.Page

  @pages [
    %Page{id: "home",  name: "Jobs",  module: HfgPortalWeb.Timekeeping.Jobs.JobsLive},
    %Page{id: "users", name: "Users", module: HfgPortalWeb.Timekeeping.Users.UsersLive},
  ]

  use HfgPortal.Helpers.DefaultAuthorize,
    roles:      @roles,
    user:       @user,
    user_role:  @user_role,
    user_roles: @user_roles,
    pages:      @pages
end
