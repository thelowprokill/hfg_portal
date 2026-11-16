defmodule HommSaves.Authorize do
  @roles      HommSaves.Users.Roles
  @user       HommSaves.Users.User
  @user_role  HommSaves.Users.UserRole
  @user_roles HommSaves.UserRoles
  alias HfgPortal.Helpers.Page

  @pages [
    %Page{id: "home",  name: "Saves", module: HfgPortalWeb.HommSaves.Files.FilesLive},
    %Page{id: "users", name: "Users", module: HfgPortalWeb.HommSaves.Users.UsersLive},
  ]

  use HfgPortal.Helpers.DefaultAuthorize,
    roles:      @roles,
    user:       @user,
    user_role:  @user_role,
    user_roles: @user_roles,
    pages:      @pages
end
