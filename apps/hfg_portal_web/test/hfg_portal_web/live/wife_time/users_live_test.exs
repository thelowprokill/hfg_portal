defmodule HfgPortalWeb.WifeTime.UsersLiveTest do
  use HfgPortalWeb.ConnCase

  use HfgPortalWeb.LiveFixtures2.UsersPageTests,
    app:        "wife_time",
    user_roles: WifeTime.UserRoles,
    module:     HfgPortalWeb.WifeTime.Users.UsersLive,
    admin_role: nil
end
