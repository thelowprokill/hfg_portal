defmodule LoanRepayment.UserRoles do
  @topic      "loan_repayment:user_roles"
  @schema      LoanRepayment.Users.UserRole
  @user_schema LoanRepayment.Users.User
  @roles       LoanRepayment.Users.Roles
  @updated     [:loan_repayment, :user_role, :updated]
  @created     [:loan_repayment, :user_role, :created]
  @deleted     [:loan_repayment, :user_role, :deleted]

  use HfgPortal.Helpers.DefaultUser, 
    schema:      @schema,
    user_schema: @user_schema,
    roles:       @roles,
    topic:       @topic,
    updated:     @updated,
    created:     @created,
    deleted:     @deleted
end
