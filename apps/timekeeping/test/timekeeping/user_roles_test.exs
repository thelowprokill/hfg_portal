defmodule Timekeeping.UserRolesTest do
  use Timekeeping.DataCase

  alias Timekeeping.{Authorize, UserRoles}
  alias Timekeeping.Users.{Roles, User, UserRole}
  alias HfgPortal.Helpers.{Search, Sort}

  defp role_fixture(user, role) do
    {:ok, ur} = UserRoles.new() |> UserRoles.create_or_update(%{user_id: user.id, role: role})
    ur
  end

  describe "Roles" do
    test "get/1 falls back to None for unknown names" do
      assert %Roles{name: "Admin", admin: true} = Roles.get("Admin")
      assert %Roles{name: "Edit", edit: true, admin: false} = Roles.get("Edit")
      assert %Roles{name: "None", view: false} = Roles.get("Bogus")
      assert %Roles{name: "None"} = Roles.get(nil)
    end
  end

  describe "UserRoles" do
    test "user_id and role are required" do
      assert {:error, cs} = UserRoles.new() |> UserRoles.create_or_update(%{})
      assert %{user_id: ["can't be blank"], role: ["can't be blank"]} = errors_on(cs)
    end

    test "create, get by user, update and delete broadcast on the role topic" do
      user = user_fixture()
      UserRoles.subscribe()

      ur = role_fixture(user, "Edit")
      assert_receive {[:timekeeping, :user_role, :created], %UserRole{role: "Edit"}}
      assert UserRoles.get(user.id, :user).id == ur.id
      assert UserRoles.get(-1, :user) == nil

      {:ok, _} = UserRoles.create_or_update(ur, %{role: "Admin"})
      assert_receive {[:timekeeping, :user_role, :updated], %UserRole{role: "Admin"}}

      {:ok, _} = UserRoles.delete(Integer.to_string(ur.id))
      assert_receive {[:timekeeping, :user_role, :deleted], %UserRole{}}
      assert UserRoles.get(ur.id) == nil
    end

    test "list/1 returns every portal user with their role struct, None when they have no role" do
      admin = user_fixture(%{username: "alice"})
      editor = user_fixture(%{username: "bob"})
      nobody = user_fixture(%{username: "carol"})
      role_fixture(admin, "Admin")
      role_fixture(editor, "Edit")

      roles = UserRoles.list(%{preload: [:user_role]}) |> Map.new(&{&1.id, &1.role.name})
      assert roles == %{admin.id => "Admin", editor.id => "Edit", nobody.id => "None"}
      assert Enum.all?(UserRoles.list(%{preload: [:user_role]}), &match?(%User{}, &1))
    end

    test "list/1 searches by user field and by role (None means no role row)" do
      admin = user_fixture(%{username: "alice"})
      _ = user_fixture(%{username: "bob"})
      nobody = user_fixture(%{username: "carol"})
      role_fixture(admin, "Admin")

      ids = fn search -> UserRoles.list(%{search_stack: search}) |> Enum.map(& &1.id) end
      assert ids.([%Search{field: :username, val: "aro"}]) == [nobody.id]
      assert ids.([%Search{field: :role, val: "Admin"}]) == [admin.id]
      assert nobody.id in ids.([%Search{field: :role, val: "None"}])
      refute admin.id in ids.([%Search{field: :role, val: "None"}])
    end

    test "list/1 sorts by role and user fields, and paginates" do
      a = user_fixture(%{username: "a_user"})
      b = user_fixture(%{username: "b_user"})
      c = user_fixture(%{username: "c_user"})
      role_fixture(a, "Edit")
      role_fixture(b, "Admin")

      by_role = UserRoles.list(%{sort_stack: [%Sort{field: :role, order: :asc}]}) |> Enum.map(& &1.id)
      assert Enum.take(by_role, 2) == [b.id, a.id]

      by_name = UserRoles.list(%{sort_stack: [%Sort{field: :username, order: :desc}]}) |> Enum.map(& &1.id)
      assert by_name == [c.id, b.id, a.id]

      page = UserRoles.list(%{sort_stack: [%Sort{field: :username, order: :asc}], page: 1, per_page: 2})
      assert Enum.map(page, & &1.id) == [c.id]
    end
  end

  describe "Authorize.authorize/3" do
    test "by role name: admin everywhere but reports, edit only home, none nowhere" do
      assert Authorize.authorize("Admin", "home")
      assert Authorize.authorize("Admin", "users")
      refute Authorize.authorize("Admin", "reports")
      assert Authorize.authorize("Edit", "home")
      refute Authorize.authorize("Edit", "users")
      refute Authorize.authorize("None", "home")
      refute Authorize.authorize("Bogus", "home")
    end

    test "dev_admin overrides the role" do
      assert Authorize.authorize("None", "users", true)
      assert Authorize.authorize("Admin", "reports", true)
    end

    test "by user role or user struct" do
      assert Authorize.authorize(%UserRole{role: "Edit"}, "home")
      assert Authorize.authorize(%User{user_role: %UserRole{role: "Admin"}, dev_admin: false}, "users")
      refute Authorize.authorize(%User{user_role: nil, dev_admin: false}, "home")
      assert Authorize.authorize(%User{user_role: nil, dev_admin: true}, "home")
    end

    test "anything else is denied" do
      refute Authorize.authorize(nil, "home")
      refute Authorize.authorize(42, "home", false)
    end
  end

  describe "Authorize.list_pages/2" do
    test "by user id follows the stored role" do
      admin = user_fixture()
      editor = user_fixture()
      nobody = user_fixture()
      role_fixture(admin, "Admin")
      role_fixture(editor, "Edit")

      assert Enum.map(Authorize.list_pages(admin.id), & &1.id) == ["home", "users"]
      assert Enum.map(Authorize.list_pages(editor.id), & &1.id) == ["home"]
      assert Authorize.list_pages(nobody.id) == []
      assert Enum.map(Authorize.list_pages(nobody.id, true), & &1.id) == ["home", "users"]
    end

    test "a portal user only gets dev access in admin mode" do
      user = user_fixture(%{dev_admin: true})
      assert Authorize.list_pages(user) == []
      assert length(Authorize.list_pages(%{user | admin_mode: true})) == 2
    end

    test "an app user uses its preloaded role" do
      user = user_fixture()
      role_fixture(user, "Edit")
      tk_user = HfgPortal.Repo.get!(User, user.id) |> HfgPortal.Repo.preload(:user_role)
      assert Enum.map(Authorize.list_pages(tk_user), & &1.id) == ["home"]
      assert Authorize.list_pages(%{tk_user | user_role: nil}) == []
    end
  end
end
