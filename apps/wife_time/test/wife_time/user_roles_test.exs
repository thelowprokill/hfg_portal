defmodule WifeTime.UserRolesTest do
  use WifeTime.DataCase

  alias WifeTime.{Authorize, UserRoles}
  alias WifeTime.Users.{Roles, User, UserRole}
  alias HfgPortal.Helpers.Search

  defp role_fixture(user, role) do
    {:ok, ur} = UserRoles.new() |> UserRoles.create_or_update(%{user_id: user.id, role: role})
    ur
  end

  test "only None and Edit roles exist; Admin falls back to None" do
    assert Enum.map(Roles.list(), & &1.name) == ["None", "Edit"]
    assert %Roles{name: "None"} = Roles.get("Admin")
  end

  test "user roles are stored per user and broadcast" do
    user = user_fixture()
    UserRoles.subscribe()
    ur = role_fixture(user, "Edit")
    assert_receive {[:wife_time, :user_role, :created], %UserRole{}}
    assert UserRoles.get(user.id, :user).id == ur.id

    assert [%User{role: %Roles{name: "Edit"}}] =
             UserRoles.list(%{search_stack: [%Search{field: :role, val: "Edit"}], preload: [:user_role]})
  end

  test "Edit sees home only; users page needs dev admin" do
    editor = user_fixture()
    role_fixture(editor, "Edit")
    nobody = user_fixture()

    assert Enum.map(Authorize.list_pages(editor.id), & &1.id) == ["home"]
    assert Authorize.list_pages(nobody.id) == []
    assert Enum.map(Authorize.list_pages(nobody.id, true), & &1.id) == ["home", "users"]
    refute Authorize.authorize("Edit", "users")
    assert Authorize.authorize("Edit", "home")
  end

  test "a role named Admin in the table grants nothing, since wife_time has no Admin role" do
    user = user_fixture()
    role_fixture(user, "Admin")
    assert Authorize.list_pages(user.id) == []
  end
end
