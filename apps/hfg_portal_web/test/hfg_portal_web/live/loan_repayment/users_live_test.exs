defmodule HfgPortalWeb.LoanRepayment.UsersLiveTest do
  use HfgPortalWeb.ConnCase

  use HfgPortalWeb.LiveFixtures2.UsersPageTests,
    app:        "loan_repayment",
    user_roles: LoanRepayment.UserRoles,
    module:     HfgPortalWeb.LoanRepayment.Users.UsersLive,
    admin_role: "Admin"
end
