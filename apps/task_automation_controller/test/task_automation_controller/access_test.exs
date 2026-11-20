defmodule TaskAutomationController.AccessTest do
  use TaskAutomationController.DataCase

  alias TaskAutomationController.{Authorize, Jobs, UserRoles}

  @all_pages ~w(home completed_jobs machines jobs priorities roles users)

  defp ids(items), do: items |> Enum.map(& &1.id) |> Enum.sort()

  defp page_ids(pages),
    do: Enum.flat_map(pages, fn p -> if p.links == [], do: [p.id], else: page_ids(p.links) end)

  describe "Jobs.list visible to a user" do
    setup do
      [ops, dev] = [role_fixture(%{name: "ops"}), role_fixture(%{name: "dev"})]
      [backup, deploy, secret] = [job_fixture(), job_fixture(), job_fixture()]
      role_job_fixture(ops, backup)
      role_job_fixture(dev, deploy)
      %{ops: ops, dev: dev, backup: backup, deploy: deploy, secret: secret}
    end

    test "without a user every job is listed", c do
      assert ids(Jobs.list(%{})) == ids([c.backup, c.deploy, c.secret])
      assert ids(Jobs.list(%{user_id: nil})) == ids([c.backup, c.deploy, c.secret])
    end

    test "a user only sees jobs linked to their roles", c do
      user = user_fixture()
      user_role_fixture(user, c.ops)
      assert ids(Jobs.list(%{user_id: user.id})) == [c.backup.id]

      user_role_fixture(user, c.dev)
      assert ids(Jobs.list(%{user_id: user.id})) == ids([c.backup, c.deploy])
    end

    test "a user with no roles sees nothing", c do
      user = user_fixture()
      assert Jobs.list(%{user_id: user.id}) == []
      # another user's roles don't leak
      user_role_fixture(user_fixture(), c.ops)
      assert Jobs.list(%{user_id: user.id}) == []
    end

    test "an admin role sees every job, including unlinked ones", c do
      user = user_fixture()
      user_role_fixture(user, role_fixture(%{admin: true}))
      assert ids(Jobs.list(%{user_id: user.id})) == ids([c.backup, c.deploy, c.secret])
    end

    test "active filter and preload still apply to a user's jobs", c do
      user = user_fixture()
      user_role_fixture(user, c.ops)
      {:ok, _} = Jobs.deactivate(c.backup)
      assert Jobs.list(%{user_id: user.id, active: true}) == []
      assert [%{priority: %Priority{}}] = Jobs.list(%{user_id: user.id, preload: [:priority]})
    end

    test "a job reachable through two of the user's roles is listed once", c do
      user = user_fixture()
      user_role_fixture(user, c.ops)
      user_role_fixture(user, c.dev)
      role_job_fixture(c.dev, c.backup)
      assert ids(Jobs.list(%{user_id: user.id})) == ids([c.backup, c.deploy])
    end
  end

  describe "UserRoles" do
    test "get(user_id, :user) returns one of the user's roles or nil" do
      user = user_fixture()
      assert UserRoles.get(user.id, :user) == nil
      ur = user_role_fixture(user, role_fixture())
      assert UserRoles.get(user.id, :user).id == ur.id
    end

    test "list_user_roles filters by user, role and active, and preloads the role" do
      [u1, u2] = [user_fixture(), user_fixture()]
      [r1, r2] = [role_fixture(), role_fixture()]
      a = user_role_fixture(u1, r1)
      b = user_role_fixture(u1, r2)
      c = user_role_fixture(u2, r1)
      {:ok, _} = UserRoles.deactivate(c)

      assert ids(UserRoles.list_user_roles(%{user_id: u1.id})) == ids([a, b])
      assert ids(UserRoles.list_user_roles(%{role_id: r1.id})) == ids([a, c])
      assert ids(UserRoles.list_user_roles(%{role_id: r1.id, active: true})) == [a.id]
      assert [%{role: %Role{id: rid}}] = UserRoles.list_user_roles(%{user_id: u2.id, preload: [:role]})
      assert rid == r1.id
    end

    test "list returns portal users, filterable by user id" do
      [u1, u2] = [user_fixture(), user_fixture()]
      user_role_fixture(u1, role_fixture())
      assert [%TaskAutomationController.Users.User{id: id}] = UserRoles.list(%{user_id: u1.id})
      assert id == u1.id
      assert u2.id in ids(UserRoles.list(%{}))
    end

    test "list returns each user once" do
      user = user_fixture()
      user_role_fixture(user, role_fixture())
      user_role_fixture(user, role_fixture())
      assert length(UserRoles.list(%{user_id: user.id})) == 1
    end

    test "preloads the user of a user role" do
      user = user_fixture()
      user_role_fixture(user, role_fixture())
      assert [%{user: %{id: id}}] = UserRoles.list_user_roles(%{user_id: user.id, preload: [:user]})
      assert id == user.id
    end

    test "deleting a role removes its user roles and role jobs" do
      role = role_fixture()
      ur = user_role_fixture(user_fixture(), role)
      rj = role_job_fixture(role, job_fixture())
      {:ok, _} = TaskAutomationController.Roles.delete(role)
      assert UserRoles.get(ur.id) == nil
      assert TaskAutomationController.RoleJobs.get(rj.id) == nil
    end
  end

  describe "Authorize.user_authorize/3 and list_pages" do
    test "a user without roles gets no pages" do
      user = user_fixture()
      assert Authorize.list_pages(user) == []
      assert Authorize.list_pages(user.id) == []
      assert Authorize.list_pages([]) == []
      assert Authorize.list_pages(nil) == []
    end

    test "any role grants home and completed jobs only" do
      user = user_fixture()
      user_role_fixture(user, role_fixture())
      assert page_ids(Authorize.list_pages(user)) == ~w(home completed_jobs)
      # the empty Manage group is dropped entirely
      refute Enum.any?(Authorize.list_pages(user), &(&1.id == "manage"))
    end

    test "an admin role gets every page, grouped under Manage" do
      user = user_fixture()
      user_role_fixture(user, role_fixture())
      user_role_fixture(user, role_fixture(%{admin: true}))
      pages = Authorize.list_pages(user.id)
      assert page_ids(pages) == @all_pages
      assert [%{id: "home"}, %{id: "completed_jobs"}, %{id: "manage", links: [_, _, _, _, _]}] = pages
    end

    test "dev admins get every page only in admin mode" do
      user = user_fixture(%{dev_admin: true})
      assert Authorize.list_pages(user) == []
      assert page_ids(Authorize.list_pages(%{user | admin_mode: true})) == @all_pages
      assert page_ids(Authorize.list_pages(user.id, true)) == @all_pages
    end

    test "user_authorize rules" do
      admin = [%UserRole{role: %Role{admin: true}}]
      plain = [%UserRole{role: %Role{admin: false}}]

      assert Authorize.user_authorize(nil, "machines", true)
      refute Authorize.user_authorize(nil, "home", false)
      assert Authorize.user_authorize(admin, "machines", false)
      refute Authorize.user_authorize(admin, "reports", false)
      assert Authorize.user_authorize(plain, "home", false)
      assert Authorize.user_authorize(plain, "completed_jobs", false)
      refute Authorize.user_authorize(plain, "jobs", false)
    end
  end

  describe "Authorize.authorize/3" do
    test "anything that isn't a role or user role is denied" do
      refute Authorize.authorize(nil, "home")
      refute Authorize.authorize("Admin", "home")
      refute Authorize.authorize(%{admin: true}, "home", false)
    end

    test "dev admins pass with any role" do
      assert Authorize.authorize(%Role{}, "machines", true)
      assert Authorize.authorize(%UserRole{role: %Role{}}, "machines", true)
    end

    test "a role or user role is checked against its admin flag" do
      assert Authorize.authorize(%Role{admin: true}, "machines")
      assert Authorize.authorize(%Role{admin: false}, "home")
      refute Authorize.authorize(%Role{admin: false}, "machines")
      assert Authorize.authorize(%UserRole{role: %Role{admin: true}}, "machines")
    end
  end
end
