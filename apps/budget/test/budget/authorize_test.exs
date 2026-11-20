defmodule Budget.AuthorizeTest do
  use Budget.DataCase

  alias Budget.{Authorize, UserRoles}
  alias Budget.Users.{Roles, UserRole}

  defp user_with_role(role, attrs \\ %{}) do
    user = user_fixture(attrs)
    if role, do: {:ok, _} = UserRoles.create_or_update(UserRoles.new(), %{user_id: user.id, role: role})
    user
  end

  defp budget_user(user), do: HfgPortal.Repo.get(Budget.Users.User, user.id) |> HfgPortal.Repo.preload(:user_role)

  defp page_ids(pages), do: Enum.map(pages, &{&1.id, Enum.map(&1.links, fn l -> l.id end)})

  @all [
    {"dashboard", []},
    {"balances", []},
    {"manage", ["accounts", "buckets", "scheduled_expenses", "transactions", "users"]}
  ]

  describe "roles" do
    test "lists the four roles with increasing rights" do
      assert Enum.map(Roles.list(), & &1.name) == ["None", "View", "Edit", "Admin"]
      assert %Roles{view: true, edit: false, admin: false} = Roles.get("View")
      assert %Roles{view: true, edit: true, admin: false} = Roles.get("Edit")
      assert %Roles{view: true, edit: true, admin: true} = Roles.get("Admin")
    end

    test "unknown or missing role names fall back to None" do
      assert Roles.get("Root").name == "None"
      assert Roles.get(nil).name == "None"
    end
  end

  describe "authorize/3" do
    test "admins can open everything but reports" do
      for page <- ~w(dashboard balances accounts buckets scheduled_expenses transactions users),
          do: assert(Authorize.authorize("Admin", page), page)

      refute Authorize.authorize("Admin", "reports")
    end

    test "view and edit roles only see the dashboard and balances" do
      for role <- ["View", "Edit"] do
        assert Authorize.authorize(role, "dashboard")
        assert Authorize.authorize(role, "balances")
        refute Authorize.authorize(role, "transactions")
        refute Authorize.authorize(role, "users")
      end
    end

    test "None, unknown roles and non-roles get nothing" do
      refute Authorize.authorize("None", "dashboard")
      refute Authorize.authorize("Root", "dashboard")
      refute Authorize.authorize(nil, "dashboard")
      refute Authorize.authorize(42, "dashboard")
    end

    test "dev_admin overrides the role" do
      assert Authorize.authorize("None", "reports", true)
    end

    test "accepts user roles and budget users" do
      assert Authorize.authorize(%UserRole{role: "View"}, "dashboard")
      refute Authorize.authorize(%UserRole{role: "View"}, "buckets")

      assert Authorize.authorize(budget_user(user_with_role("Admin")), "users")
      refute Authorize.authorize(budget_user(user_with_role(nil)), "dashboard")
    end
  end

  describe "list_pages/2" do
    test "by role" do
      assert page_ids(Authorize.list_pages(user_with_role("Admin").id)) == @all
      assert page_ids(Authorize.list_pages(user_with_role("Edit").id)) == [{"dashboard", []}, {"balances", []}]
      assert page_ids(Authorize.list_pages(user_with_role("View").id)) == [{"dashboard", []}, {"balances", []}]
      assert Authorize.list_pages(user_with_role("None").id) == []
      assert Authorize.list_pages(user_with_role(nil).id) == []
    end

    test "accepts budget users and portal users" do
      assert page_ids(Authorize.list_pages(budget_user(user_with_role("View")))) == [{"dashboard", []}, {"balances", []}]
      assert page_ids(Authorize.list_pages(user_with_role("Admin"))) == @all
    end

    test "a dev admin only gets everything while in admin mode" do
      dev = user_with_role(nil, %{dev_admin: true})
      assert Authorize.list_pages(dev) == []
      assert page_ids(Authorize.list_pages(%{dev | admin_mode: true})) == @all

      viewer = user_with_role("View", %{dev_admin: true})
      assert page_ids(Authorize.list_pages(%{viewer | admin_mode: true})) == @all
    end
  end

  describe "can_edit?/1" do
    test "edit and admin roles can, view/none/no role cannot" do
      assert Authorize.can_edit?(user_with_role("Edit"))
      assert Authorize.can_edit?(user_with_role("Admin").id)
      refute Authorize.can_edit?(user_with_role("View"))
      refute Authorize.can_edit?(user_with_role("None"))
      refute Authorize.can_edit?(user_with_role(nil))
    end

    test "dev admins can only while in admin mode" do
      dev = user_with_role(nil, %{dev_admin: true})
      refute Authorize.can_edit?(dev)
      assert Authorize.can_edit?(%{dev | admin_mode: true})
    end
  end

  describe "user roles" do
    test "get by user id" do
      user = user_with_role("Edit")
      assert %UserRole{role: "Edit"} = UserRoles.get(user.id, :user)
      assert UserRoles.get(user_fixture().id, :user) == nil
    end

    test "changeset requires user and role" do
      assert %{user_id: [_], role: [_]} = errors_on(UserRole.changeset(%UserRole{}, %{}))
    end

    test "list maps every portal user to a role struct, None when unassigned" do
      admin = user_with_role("Admin", %{username: "a_admin"})
      plain = user_with_role(nil, %{username: "b_plain"})

      roles = UserRoles.list(%{preload: [:user_role]}) |> Map.new(&{&1.id, &1.role.name})
      assert roles == %{admin.id => "Admin", plain.id => "None"}

      assert [%{id: id}] = UserRoles.list(%{preload: [:user_role], search_stack: [%{field: :role, val: "None"}]})
      assert id == plain.id

      assert [%{id: ^id}] = UserRoles.list(%{search_stack: [%{field: :username, val: "plain"}]})
    end

    test "update and delete broadcast" do
      UserRoles.subscribe()
      user = user_with_role("View")
      assert_receive {[:budget, :user_role, :created], %UserRole{role: "View"}}

      {:ok, ur} = UserRoles.create_or_update(UserRoles.get(user.id, :user), %{role: "Edit"})
      assert_receive {[:budget, :user_role, :updated], %UserRole{role: "Edit"}}

      {:ok, _} = UserRoles.delete(Integer.to_string(ur.id))
      assert_receive {[:budget, :user_role, :deleted], _}
      assert UserRoles.get(user.id, :user) == nil
    end
  end
end
