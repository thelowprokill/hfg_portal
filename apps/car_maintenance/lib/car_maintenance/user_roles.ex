defmodule CarMaintenance.UserRoles do
  @topic      "car_maintenance:user_roles"
  @schema      CarMaintenance.Users.UserRole
  @user_schema CarMaintenance.Users.User
  @roles       CarMaintenance.Users.Roles
  @updated     [:car_maintenance, :user_role, :updated]
  @created     [:car_maintenance, :user_role, :created]
  @deleted     [:car_maintenance, :user_role, :deleted]

  use HfgPortal.Helpers.DefaultUser, 
    schema:      @schema,
    user_schema: @user_schema,
    roles:       @roles,
    topic:       @topic,
    updated:     @updated,
    created:     @created,
    deleted:     @deleted
end
