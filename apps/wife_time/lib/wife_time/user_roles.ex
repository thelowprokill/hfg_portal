defmodule WifeTime.UserRoles do
  @topic      "wife_time:user_roles"
  @schema      WifeTime.Users.UserRole
  @user_schema WifeTime.Users.User
  @roles       WifeTime.Users.Roles
  @updated     [:wife_time, :user_role, :updated]
  @created     [:wife_time, :user_role, :created]
  @deleted     [:wife_time, :user_role, :deleted]

  use HfgPortal.Helpers.DefaultUser, 
    schema:      @schema,
    user_schema: @user_schema,
    roles:       @roles,
    topic:       @topic,
    updated:     @updated,
    created:     @created,
    deleted:     @deleted
end
