defmodule TaskAutomationController.CrudTest do
  use TaskAutomationController.DataCase

  alias TaskAutomationController.{Jobs, Machines, Schedules, Roles, RoleJobs, Users}
  alias TaskAutomationController.Jobs.{Statuses, Types}
  alias HfgPortal.Helpers.{Search, Sort}

  describe "changesets" do
    test "job requires name, address and priority; defaults to active and synchronous" do
      assert %{name: _, address: _, priority_id: _} = errors_on(Jobs.change(Jobs.new(), %{}))
      assert {:error, _} = Jobs.create_or_update(Jobs.new(), %{name: "x", address: "y"})

      job = job_fixture(%{avg_runtime: 30})
      assert job.active
      refute job.asynchronous
      assert job.avg_runtime == 30
    end

    test "machine requires name and address" do
      assert %{name: _, address: _} = errors_on(Machines.change(Machines.new(), %{description: "d"}))
      assert Machines.change(Machines.new(), %{name: "n", address: "a"}).valid?
    end

    test "schedule requires name, job, day_of_week and time_of_day and casts the time" do
      assert %{name: _, job_id: _, day_of_week: _, time_of_day: _} = errors_on(Schedules.change(Schedules.new(), %{}))
      assert %{time_of_day: ["is invalid"]} = errors_on(Schedules.change(Schedules.new(), %{time_of_day: "25:99"}))

      job = job_fixture()
      s = create!(Schedules, %{name: "nightly", job_id: job.id, day_of_week: 1, time_of_day: "02:30:00"})
      assert s.time_of_day == ~T[02:30:00]
      assert Schedules.get(s.id).day_of_week == 1
    end

    test "queue item requires job, status and type" do
      assert %{job_id: _, status: _, type: _} = errors_on(TaskAutomationController.QueuedItems.change(%Queue{}, %{}))
    end

    test "role has no required fields and ignores unknown attrs" do
      assert Roles.change(Roles.new(), %{}).valid?
    end

    test "role admin flag can be set through the context" do
      role = create!(Roles, %{name: "Admins", admin: true})
      assert Roles.get(role.id).admin
    end

    test "user role requires user and role" do
      assert %{user_id: _, role_id: _} = errors_on(TaskAutomationController.UserRoles.change(%UserRole{}, %{}))
    end

    test "a new user role is active by default" do
      ur = create!(TaskAutomationController.UserRoles, %{user_id: user_fixture().id, role_id: role_fixture().id})
      assert ur.active
    end
  end

  describe "generic CRUD (DefaultCrud) through Machines" do
    test "create, get, update, deactivate/activate, delete" do
      m = machine_fixture(%{name: "box"})
      assert Machines.get(m.id).name == "box"

      {:ok, m} = Machines.create_or_update(m, %{name: "box2"})
      assert Machines.get(m.id).name == "box2"

      {:ok, _} = Machines.deactivate(m.id)
      refute Machines.get(m.id).active
      {:ok, _} = Machines.activate(m.id)
      assert Machines.get(m.id).active

      {:ok, _} = Machines.delete(m.id)
      assert Machines.get(m.id) == nil
    end

    test "update with invalid attrs returns the changeset and leaves the row" do
      m = machine_fixture(%{name: "box"})
      assert {:error, %Ecto.Changeset{}} = Machines.create_or_update(m, %{name: nil})
      assert Machines.get(m.id).name == "box"
    end

    test "list filters by active, searches with LIKE, sorts and paginates (0-based pages)" do
      a = machine_fixture(%{name: "alpha"})
      b = machine_fixture(%{name: "beta"})
      c = machine_fixture(%{name: "alphabet", active: false})

      assert ids(Machines.list(%{active: true})) == ids([a, b])
      assert ids(Machines.list(%{active: false})) == [c.id]
      assert ids(Machines.list(%{search_stack: [%Search{field: :name, val: "alpha"}]})) == ids([a, c])
      # an empty search matches everything; unknown fields are ignored
      assert length(Machines.list(%{search_stack: [%Search{field: :name, val: ""}, %Search{field: :nope, val: "x"}]})) == 3

      sorted = %{sort_stack: [%Sort{field: :name, order: :desc}]}
      assert Enum.map(Machines.list(sorted), & &1.name) == ["beta", "alphabet", "alpha"]
      assert Enum.map(Machines.list(Map.merge(sorted, %{page: 0, per_page: 2})), & &1.name) == ["beta", "alphabet"]
      assert Enum.map(Machines.list(Map.merge(sorted, %{page: "1", per_page: "2"})), & &1.name) == ["alpha"]
    end

    test "search on timestamps means 'on or after'" do
      m = machine_fixture()
      assert ids(Machines.list(%{search_stack: [%Search{field: :inserted_at, val: m.inserted_at}]})) == [m.id]
      later = NaiveDateTime.add(m.inserted_at, 60)
      assert Machines.list(%{search_stack: [%Search{field: :inserted_at, val: later}]}) == []
    end
  end

  describe "PubSub" do
    test "create, update and delete broadcast on the topic and the per-id topic" do
      Machines.subscribe()
      m = machine_fixture()
      assert_receive {[:machine, :created], %Machine{id: id}} when id == m.id

      Machines.subscribe(m.id)
      {:ok, _} = Machines.create_or_update(m, %{name: "renamed"})
      assert_receive {[:machine, :updated], %Machine{name: "renamed"}}
      assert_receive {[:machine, :updated], %Machine{name: "renamed"}}

      {:ok, _} = Machines.delete(m)
      assert_receive {[:machine, :deleted], _}
    end

    test "failed writes don't broadcast" do
      Jobs.subscribe()
      {:error, _} = Jobs.create_or_update(Jobs.new(), %{})
      refute_receive {[:job, _], _}
    end

    test "each context uses its own topic and event names" do
      for {ctx, _event} <- [
            {Jobs, [:job, :created]},
            {Schedules, [:schedule, :created]},
            {Roles, [:role, :created]},
            {RoleJobs, [:task_automation_controller, :role_job, :created]},
            {TaskAutomationController.UserRoles, [:task_automation_controller, :user_role, :created]},
            {TaskAutomationController.Priorities, [:priority, :created]},
            {TaskAutomationController.QueuedItems, [:queued_item, :created]}
          ],
          do: ctx.subscribe()

      job = job_fixture()
      create!(Schedules, %{name: "s", job_id: job.id, day_of_week: 0, time_of_day: ~T[00:00:00]})
      role = create!(Roles, %{name: "r"})
      role_job_fixture(role, job)
      user_role_fixture(user_fixture(), role)
      queue_fixture(%{job_id: job.id})

      for event <- [[:priority, :created], [:job, :created], [:schedule, :created], [:role, :created],
                    [:task_automation_controller, :role_job, :created],
                    [:task_automation_controller, :user_role, :created], [:queued_item, :created]],
          do: assert_receive({^event, _})

      Machines.subscribe()
      refute_received {[:machine, _], _}
    end

    test "unsubscribe stops delivery" do
      Machines.subscribe()
      Machines.unsubscribe()
      machine_fixture()
      refute_receive {[:machine, :created], _}
    end
  end

  describe "Schedules.list" do
    test "filters by job" do
      [j1, j2] = [job_fixture(), job_fixture()]
      s1 = create!(Schedules, %{name: "a", job_id: j1.id, day_of_week: 1, time_of_day: ~T[08:00:00]})
      s2 = create!(Schedules, %{name: "b", job_id: j2.id, day_of_week: 5, time_of_day: ~T[09:00:00], active: false})

      assert ids(Schedules.list(%{job_id: j1.id})) == [s1.id]
      assert ids(Schedules.list(%{})) == ids([s1, s2])
      assert ids(Schedules.list(%{active: true})) == [s1.id]
    end

    test "are deleted with their job" do
      job = job_fixture()
      s = create!(Schedules, %{name: "a", job_id: job.id, day_of_week: 1, time_of_day: ~T[08:00:00]})
      {:ok, _} = Jobs.delete(job)
      assert Schedules.get(s.id) == nil
    end
  end

  describe "RoleJobs" do
    test "list_user_roles lists, filters by active and preloads" do
      [role, job] = [role_fixture(), job_fixture()]
      rj = role_job_fixture(role, job)
      off = create!(RoleJobs, %{role_id: role.id, job_id: job_fixture().id, active: false})

      assert ids(RoleJobs.list_user_roles(%{})) == ids([rj, off])
      assert [%{role: %Role{}, job: %Job{}}] = RoleJobs.list_user_roles(%{active: true, preload: [:role, :job]})
    end
  end

  describe "Users (read-only mapping of portal users)" do
    test "get/list read portal users from the hfg_portal users table" do
      u = user_fixture(%{first_name: "Ann"})
      assert %TaskAutomationController.Users.User{username: name, first_name: "Ann"} = Users.get(u.id)
      assert name == u.username
      assert u.id in ids(Users.list(%{}))
    end

    test "changeset casts nothing" do
      refute Users.change(Users.get(user_fixture().id), %{username: "hacked"}).changes |> Map.has_key?(:username)
    end

    test "preloads a user's roles" do
      u = user_fixture()
      role = role_fixture()
      user_role_fixture(u, role)
      assert [%{role_id: rid}] = Users.get(u.id) |> Users.preload(%{preload: [:user_roles]}) |> Map.get(:user_roles)
      assert rid == role.id
    end
  end

  describe "Statuses and Types" do
    test "list the known values and look them up by display name" do
      assert Enum.map(Statuses.list(), & &1.id) == ~w(unassigned waiting running completed failed)
      assert %Statuses{id: "running"} = Statuses.get("Running")
      assert Statuses.get("running") == nil
      assert Enum.map(Types.list(), & &1.id) == ~w(user scheduled)
      assert %Types{id: "scheduled"} = Types.get("Scheduled")
      assert Types.get("nope") == nil
    end
  end

  defp ids(items), do: items |> Enum.map(& &1.id) |> Enum.sort()
end
