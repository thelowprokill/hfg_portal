defmodule CarMaintenance.UsersTest do
  use CarMaintenance.DataCase

  alias CarMaintenance.{Authorize, UserRoles}
  alias CarMaintenance.Users.{Roles, User, UserRole}

  defp role_fixture(user, role) do
    {:ok, ur} = UserRoles.create_or_update(%UserRole{}, %{user_id: user.id, role: role})
    ur
  end

  describe "Roles" do
    test "only None and Edit are offered" do
      assert Roles.list() |> Enum.map(& &1.name) == ["None", "Edit"]
    end

    test "get/1 resolves known names and falls back to None for anything else" do
      assert %Roles{name: "Edit", edit: true, view: true, admin: false} = Roles.get("Edit")
      for name <- ["View", "Admin", "edit", "", nil] do
        assert %Roles{name: "None", edit: false, view: false, admin: false} = Roles.get(name)
      end
    end
  end

  describe "UserRole.changeset/2" do
    test "requires user_id and role" do
      assert %{user_id: ["can't be blank"], role: ["can't be blank"]} = errors_on(UserRole.changeset(%UserRole{}, %{}))
      assert UserRole.changeset(%UserRole{}, %{user_id: 1, role: "Edit"}).valid?
    end
  end

  describe "UserRoles" do
    test "create_or_update/2 inserts, updates and broadcasts" do
      user = user_fixture()
      UserRoles.subscribe()
      ur = role_fixture(user, "Edit")
      assert_receive {[:car_maintenance, :user_role, :created], %UserRole{role: "Edit"}}

      {:ok, ur2} = UserRoles.create_or_update(ur, %{role: "None"})
      assert ur2.id == ur.id
      assert_receive {[:car_maintenance, :user_role, :updated], %UserRole{role: "None"}}
    end

    test "create_or_update/2 with missing fields returns an error and broadcasts nothing" do
      UserRoles.subscribe()
      assert {:error, cs} = UserRoles.create_or_update(%UserRole{}, %{role: "Edit"})
      assert %{user_id: ["can't be blank"]} = errors_on(cs)
      refute_receive _
    end

    test "get/2 by user id, get/1 by role id" do
      user = user_fixture()
      ur = role_fixture(user, "Edit")
      assert UserRoles.get(user.id, :user).id == ur.id
      assert UserRoles.get(ur.id).user_id == user.id
      assert UserRoles.get(user_fixture().id, :user) == nil
    end

    test "delete/1 accepts a struct, an integer id or a string id" do
      [a, b, c] = for _ <- 1..3, do: role_fixture(user_fixture(), "Edit")
      UserRoles.subscribe()
      assert {:ok, _} = UserRoles.delete(a)
      assert {:ok, _} = UserRoles.delete(b.id)
      assert {:ok, _} = UserRoles.delete(Integer.to_string(c.id))
      for _ <- 1..3, do: assert_receive({[:car_maintenance, :user_role, :deleted], %UserRole{}})
      assert UserRoles.get(c.id) == nil
    end

    test "new/0, new_changeset/1, change/2" do
      assert %UserRole{} = UserRoles.new()
      refute UserRoles.new_changeset(%{}).valid?
      assert UserRoles.change(%UserRole{}, %{user_id: 1, role: "Edit"}).valid?
    end
  end

  describe "UserRoles.list/1" do
    setup do
      alice = user_fixture(%{username: "alice", first_name: "Alice"})
      bob = user_fixture(%{username: "bob"})
      carol = user_fixture(%{username: "carol"})
      role_fixture(alice, "Edit")
      role_fixture(carol, "Bogus")
      %{alice: alice, bob: bob, carol: carol}
    end

    defp names(users), do: Enum.map(users, & &1.username)

    test "returns every portal user with a resolved role struct" do
      users = UserRoles.list(%{preload: [:user_role], sort_stack: [%{field: :username, order: :asc}]})
      assert names(users) == ["alice", "bob", "carol"]
      assert Enum.map(users, & &1.role.name) == ["Edit", "None", "None"]
      assert %User{} = hd(users)
    end

    test "search by role, where None also matches users without a role row" do
      edit = UserRoles.list(%{preload: [:user_role], search_stack: [%{field: :role, val: "Edit"}]})
      assert names(edit) == ["alice"]
      none = UserRoles.list(%{preload: [:user_role], search_stack: [%{field: :role, val: "None"}], sort_stack: [%{field: :username, order: :asc}]})
      assert names(none) == ["bob"]
    end

    test "search by a user field" do
      assert names(UserRoles.list(%{preload: [:user_role], search_stack: [%{field: :username, val: "ob"}]})) == ["bob"]
      assert names(UserRoles.list(%{preload: [:user_role], search_stack: [%{field: :first_name, val: "Ali"}]})) == ["alice"]
    end

    test "sort by role and paginate" do
      users = UserRoles.list(%{preload: [:user_role], sort_stack: [%{field: :role, order: :asc}, %{field: :username, order: :asc}]})
      # NULL roles sort last ascending in Postgres
      assert names(users) == ["carol", "alice", "bob"]
      assert names(UserRoles.list(%{sort_stack: [%{field: :username, order: :desc}], page: 0, per_page: 1})) == ["carol"]
    end
  end

  describe "Authorize.authorize/3" do
    test "by role name" do
      assert Authorize.authorize("Edit", "home")
      refute Authorize.authorize("Edit", "users")
      refute Authorize.authorize("None", "home")
      refute Authorize.authorize("Unknown", "home")
    end

    test "dev_admin can open any page" do
      assert Authorize.authorize("None", "users", true)
      assert Authorize.authorize("None", "anything", true)
    end

    test "role structs: admin sees everything but reports, view sees home" do
      assert Authorize.authorize(%Roles{admin: true}, "users")
      refute Authorize.authorize(%Roles{admin: true}, "reports")
      assert Authorize.authorize(%Roles{view: true}, "home")
      refute Authorize.authorize(%Roles{view: true}, "users")
    end

    test "by UserRole and by User" do
      assert Authorize.authorize(%UserRole{role: "Edit"}, "home")
      refute Authorize.authorize(%UserRole{role: "None"}, "home")
      assert Authorize.authorize(%User{user_role: %UserRole{role: "Edit"}, dev_admin: false}, "home")
      refute Authorize.authorize(%User{user_role: nil, dev_admin: false}, "home")
      assert Authorize.authorize(%User{user_role: nil, dev_admin: true}, "users")
    end

    test "anything else is denied" do
      refute Authorize.authorize(nil, "home")
      refute Authorize.authorize(:edit, "home")
      refute Authorize.authorize(42, "home", false)
    end
  end

  describe "Authorize.list_pages/2" do
    defp ids(pages), do: Enum.map(pages, & &1.id)

    test "from a UserRole" do
      assert ids(Authorize.list_pages(%UserRole{role: "Edit"})) == ["home"]
      assert Authorize.list_pages(%UserRole{role: "None"}) == []
      assert ids(Authorize.list_pages(%UserRole{role: "None"}, true)) == ["home", "users"]
    end

    test "no role at all" do
      assert Authorize.list_pages(nil) == []
      assert ids(Authorize.list_pages(nil, true)) == ["home", "users"]
    end

    test "from a user id, looked up in the database" do
      user = user_fixture()
      assert Authorize.list_pages(user.id) == []
      role_fixture(user, "Edit")
      assert ids(Authorize.list_pages(user.id)) == ["home"]
    end

    test "from the app's User: dev admin only counts in admin mode" do
      user = %User{user_role: %UserRole{role: "Edit"}, dev_admin: true, admin_mode: false}
      assert ids(Authorize.list_pages(user)) == ["home"]
      assert ids(Authorize.list_pages(%{user | admin_mode: true})) == ["home", "users"]
      assert Authorize.list_pages(%User{user_role: nil, dev_admin: false, admin_mode: true}) == []
    end

    test "from a portal account user" do
      user = user_fixture()
      account = HfgPortal.Repo.get!(HfgPortal.Accounts.User, user.id)
      assert Authorize.list_pages(account) == []
      role_fixture(user, "Edit")
      assert ids(Authorize.list_pages(account)) == ["home"]
      assert ids(Authorize.list_pages(%{account | dev_admin: true, admin_mode: true})) == ["home", "users"]
    end
  end
end
