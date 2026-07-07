defmodule Timekeeping.UserRoles do
  @topic      "timekeeping:user_roles"
  @schema      Timekeeping.Users.UserRole
  @user_schema Timekeeping.Users.User
  @roles       Timekeeping.Users.Roles
  @updated     [:timekeeping, :user_role, :updated]
  @created     [:timekeeping, :user_role, :created]
  @deleted     [:timekeeping, :user_role, :deleted]

  use HfgPortal.Helpers.DefaultUser,
    schema:      @schema,
    user_schema: @user_schema,
    roles:       @roles,
    topic:       @topic,
    updated:     @updated,
    created:     @created,
    deleted:     @deleted
end
