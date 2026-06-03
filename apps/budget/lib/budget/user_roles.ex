defmodule Budget.UserRoles do
  @topic       "budget:user_roles"
  @schema      Budget.Users.UserRole
  @user_schema Budget.Users.User
  @roles       Budget.Users.Roles
  @updated     [:budget, :user_role, :updated]
  @created     [:budget, :user_role, :created]
  @deleted     [:budget, :user_role, :deleted]

  use HfgPortal.Helpers.DefaultUser,
    schema:      @schema,
    user_schema: @user_schema,
    roles:       @roles,
    topic:       @topic,
    updated:     @updated,
    created:     @created,
    deleted:     @deleted
end
