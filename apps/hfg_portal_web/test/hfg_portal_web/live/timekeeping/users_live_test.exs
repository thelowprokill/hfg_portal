defmodule HfgPortalWeb.Timekeeping.UsersLiveTest do
  use HfgPortalWeb.ConnCase

  use HfgPortalWeb.LiveFixtures2.UsersPageTests,
    app:        "timekeeping",
    user_roles: Timekeeping.UserRoles,
    module:     HfgPortalWeb.Timekeeping.Users.UsersLive,
    admin_role: "Admin"
end
