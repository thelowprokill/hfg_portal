defmodule LoanRepayment.UsersTest do
  use LoanRepayment.DataCase

  alias LoanRepayment.{Authorize, UserRoles}
  alias LoanRepayment.Users.{Roles, User, UserRole}

  defp role_fixture(user, role) do
    {:ok, ur} = UserRoles.create_or_update(%UserRole{}, %{user_id: user.id, role: role})
    ur
  end

  defp ids(pages), do: Enum.map(pages, & &1.id)

  describe "Roles" do
    test "lists None, View, Edit, Admin with increasing rights" do
      assert [
               %Roles{name: "None", view: false, edit: false, admin: false},
               %Roles{name: "View", view: true, edit: false, admin: false},
               %Roles{name: "Edit", view: true, edit: true, admin: false},
               %Roles{name: "Admin", view: true, edit: true, admin: true},
             ] = Roles.list()
    end

    test "get/1 falls back to None" do
      assert Roles.get("Admin").admin
      assert Roles.get("admin").name == "None"
      assert Roles.get(nil).name == "None"
    end
  end

  describe "UserRoles" do
    test "create_or_update/2 validates, persists and broadcasts" do
      user = user_fixture()
      UserRoles.subscribe()
      assert {:error, cs} = UserRoles.create_or_update(%UserRole{}, %{user_id: user.id})
      assert %{role: ["can't be blank"]} = errors_on(cs)
      ur = role_fixture(user, "View")
      assert_receive {[:loan_repayment, :user_role, :created], %UserRole{role: "View"}}
      assert UserRoles.get(user.id, :user).id == ur.id
      {:ok, _} = UserRoles.delete(Integer.to_string(ur.id))
      assert_receive {[:loan_repayment, :user_role, :deleted], %UserRole{}}
      assert UserRoles.get(user.id, :user) == nil
    end

    test "list/1 resolves roles and filters by role" do
      a = user_fixture(%{username: "ann"})
      b = user_fixture(%{username: "ben"})
      role_fixture(a, "Admin")
      users = UserRoles.list(%{preload: [:user_role], sort_stack: [%{field: :username, order: :asc}]})
      assert Enum.map(users, &{&1.username, &1.role.name}) == [{"ann", "Admin"}, {"ben", "None"}]
      assert [%User{id: id}] = UserRoles.list(%{preload: [:user_role], search_stack: [%{field: :role, val: "None"}]})
      assert id == b.id
    end
  end

  describe "Authorize.authorize/3" do
    test "View and Edit can open home; None cannot" do
      assert Authorize.authorize("View", "home")
      assert Authorize.authorize("Edit", "home")
      refute Authorize.authorize("None", "home")
      refute Authorize.authorize("Garbage", "home")
    end

    test "nobody but dev admins can open users" do
      for role <- ["None", "View", "Edit"], do: refute(Authorize.authorize(role, "users"))
      assert Authorize.authorize("None", "users", true)
    end

    test "Admin can open users" do
      assert Authorize.authorize("Admin", "users")
    end

    test "UserRole, User and fallbacks" do
      assert Authorize.authorize(%UserRole{role: "View"}, "home")
      assert Authorize.authorize(%User{user_role: %UserRole{role: "Edit"}, dev_admin: false}, "home")
      refute Authorize.authorize(%User{user_role: nil, dev_admin: false}, "home")
      assert Authorize.authorize(%User{user_role: nil, dev_admin: true}, "users")
      refute Authorize.authorize(nil, "home")
      refute Authorize.authorize(7, "home")
    end
  end

  describe "Authorize.list_pages/2" do
    test "from a UserRole / nil" do
      assert ids(Authorize.list_pages(%UserRole{role: "View"})) == ["home"]
      assert Authorize.list_pages(%UserRole{role: "None"}) == []
      assert ids(Authorize.list_pages(%UserRole{role: "None"}, true)) == ["home", "users"]
      assert Authorize.list_pages(nil) == []
      assert ids(Authorize.list_pages(nil, true)) == ["home", "users"]
    end

    test "from a user id and from a portal account" do
      user = user_fixture()
      account = HfgPortal.Repo.get!(HfgPortal.Accounts.User, user.id)
      assert Authorize.list_pages(user.id) == []
      assert Authorize.list_pages(account) == []
      role_fixture(user, "Edit")
      assert ids(Authorize.list_pages(user.id)) == ["home"]
      assert ids(Authorize.list_pages(account)) == ["home"]
      assert ids(Authorize.list_pages(%{account | dev_admin: true, admin_mode: true})) == ["home", "users"]
      assert ids(Authorize.list_pages(%{account | dev_admin: true, admin_mode: false})) == ["home"]
    end

    test "from the app's User" do
      user = %User{user_role: %UserRole{role: "View"}, dev_admin: true, admin_mode: false}
      assert ids(Authorize.list_pages(user)) == ["home"]
      assert ids(Authorize.list_pages(%{user | admin_mode: true})) == ["home", "users"]
    end
  end
end
