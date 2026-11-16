defmodule HommSaves.UserRoles do
  @topic      "homm_saves:user_roles"
  @schema      HommSaves.Users.UserRole
  @user_schema HommSaves.Users.User
  @roles       HommSaves.Users.Roles
  @updated     [:homm_saves, :user_role, :updated]
  @created     [:homm_saves, :user_role, :created]
  @deleted     [:homm_saves, :user_role, :deleted]

  use HfgPortal.Helpers.DefaultUser,
    schema:      @schema,
    user_schema: @user_schema,
    roles:       @roles,
    topic:       @topic,
    updated:     @updated,
    created:     @created,
    deleted:     @deleted
end
