defmodule HommSaves.UserRolesTest do
  use HommSaves.DataCase

  alias HommSaves.{Authorize, UserRoles}
  alias HommSaves.Users.{Roles, User, UserRole}

  defp role_fixture(user, role) do
    {:ok, ur} = UserRoles.new() |> UserRoles.create_or_update(%{user_id: user.id, role: role})
    ur
  end

  test "roles: None, Edit, Admin; unknown is None" do
    assert Enum.map(Roles.list(), & &1.name) == ["None", "Edit", "Admin"]
    assert %Roles{name: "None"} = Roles.get("View")
  end

  test "role rows are created, listed and broadcast on the homm_saves topic" do
    user = user_fixture()
    UserRoles.subscribe()
    role_fixture(user, "Admin")
    assert_receive {[:homm_saves, :user_role, :created], %UserRole{role: "Admin"}}

    assert [%User{role: %Roles{name: "Admin"}}] =
             UserRoles.list(%{preload: [:user_role]}) |> Enum.filter(&(&1.id == user.id))
  end

  test "the Saves page is open to Edit and Admin, Users only to Admin" do
    admin = user_fixture()
    editor = user_fixture()
    role_fixture(admin, "Admin")
    role_fixture(editor, "Edit")

    assert Enum.map(Authorize.list_pages(admin.id), & &1.name) == ["Saves", "Users"]
    assert Enum.map(Authorize.list_pages(editor.id), & &1.name) == ["Saves"]
    assert Authorize.list_pages(user_fixture().id) == []
    assert Authorize.authorize(%UserRole{role: "Edit"}, "home")
    refute Authorize.authorize(%UserRole{role: "Edit"}, "users")
  end
end
