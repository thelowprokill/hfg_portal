defmodule HfgPortalWeb.CarMaintenance.UsersLiveTest do
  use HfgPortalWeb.ConnCase

  use HfgPortalWeb.LiveFixtures2.UsersPageTests,
    app:        "car_maintenance",
    user_roles: CarMaintenance.UserRoles,
    module:     HfgPortalWeb.CarMaintenance.Users.UsersLive,
    admin_role: nil
end
