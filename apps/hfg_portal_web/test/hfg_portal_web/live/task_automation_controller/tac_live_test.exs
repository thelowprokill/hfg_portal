defmodule HfgPortalWeb.TaskAutomationController.LiveTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortal.AccountsFixtures
  import HfgPortalWeb.LiveHelpers

  alias TaskAutomationController.{Jobs, Machines, Priorities, QueuedItems, RoleJobs, Roles}
  alias TaskAutomationController.Jobs.{Job, Machine, Priority, Queue}

  @home HfgPortalWeb.Home.HomeLive
  @tac_home HfgPortalWeb.TaskAutomationController.Home.HomeLive

  @manage %{
    "task_automation_controller,manage,machines"   => HfgPortalWeb.TaskAutomationController.Manage.Machines.MachinesLive,
    "task_automation_controller,manage,jobs"       => HfgPortalWeb.TaskAutomationController.Manage.Jobs.JobsLive,
    "task_automation_controller,manage,priorities" => HfgPortalWeb.TaskAutomationController.Manage.Priorities.PrioritiesLive,
    "task_automation_controller,manage,roles"      => HfgPortalWeb.TaskAutomationController.Manage.Roles.RolesLive,
    "task_automation_controller,manage,users"      => HfgPortalWeb.TaskAutomationController.Manage.Users.UsersLive
  }

  defp priority!(name \\ "High") do
    {:ok, p} = Priorities.create_or_update(%Priority{}, %{name: name})
    p
  end

  defp job!(priority, name) do
    {:ok, j} = Jobs.create_or_update(%Job{}, %{name: name, address: "/#{name}", priority_id: priority.id})
    j
  end

  defp machine!(name \\ "worker1") do
    {:ok, m} = Machines.create_or_update(%Machine{}, %{name: name, address: "http://#{name}"})
    m
  end

  defp queue!(job, status) do
    {:ok, q} = QueuedItems.create_or_update(%Queue{}, %{job_id: job.id, status: status, type: "user"})
    q
  end

  defp allow_job(role, job), do: {:ok, _} = RoleJobs.create_or_update(%TaskAutomationController.Users.RoleJob{}, %{role_id: role.id, job_id: job.id, active: true})

  describe "access" do
    test "no role: nothing", %{conn: conn} do
      conn = log_in(conn, user_fixture())
      assert rendered_module(conn, "task_automation_controller,home") == @home
      assert rendered_module(conn, "task_automation_controller,completed_jobs") == @home
      for {page, _} <- @manage, do: assert(rendered_module(conn, page) == @home)
    end

    test "a plain role: home and completed jobs, no manage pages", %{conn: conn} do
      user = user_fixture()
      tac_role(user)
      conn = log_in(conn, user)

      assert rendered_module(conn, "task_automation_controller,home") == @tac_home
      assert rendered_module(conn, "task_automation_controller,completed_jobs") == @tac_home
      for {page, _} <- @manage, do: assert(rendered_module(conn, page) == @home, page)
    end

    test "an admin role: everything", %{conn: conn} do
      user = user_fixture()
      tac_role(user, admin: true)
      conn = log_in(conn, user)

      for {page, module} <- @manage, do: assert(rendered_module(conn, page) == module, page)
    end

    test "dev admin in admin mode: everything without a role", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{dev_admin: true}))
      for {page, module} <- @manage, do: assert(rendered_module(conn, page, "&admin=true") == module)
      assert rendered_module(conn, "task_automation_controller,manage,jobs") == @home
    end
  end

  describe "home (queue)" do
    setup %{conn: conn} do
      user = user_fixture()
      role = tac_role(user)
      p = priority!()
      allowed = job!(p, "backup")
      other = job!(p, "deploy_prod")
      allow_job(role, allowed)
      %{conn: log_in(conn, user), user: user, allowed: allowed, other: other}
    end

    test "open items on home, finished ones on completed jobs", %{conn: conn, allowed: job} do
      open = queue!(job, "running")
      done = queue!(job, "completed")
      failed = queue!(job, "failed")

      {_view, page} = open_page(conn, "task_automation_controller,home")
      assert has_element?(page, "td", "#{open.id}")
      refute has_element?(page, "td", ~r/^#{done.id}$/)
      assert render(page) =~ "RUNNING"

      {_view, page} = open_page(conn, "task_automation_controller,completed_jobs")
      html = render(page)
      assert html =~ "COMPLETED"
      assert html =~ "FAILED"
      refute html =~ "RUNNING"
      assert has_element?(page, "td", ~r/^#{failed.id}$/)
    end

    test "add job offers only the jobs the user's roles allow and queues it", %{conn: conn, allowed: allowed, other: other, user: user} do
      {_view, page} = open_page(conn, "task_automation_controller,home")
      render_click(page, "add_new")

      assert has_element?(page, "#new_job_modal option[value='#{allowed.id}']")
      refute has_element?(page, "#new_job_modal option[value='#{other.id}']")

      page |> element("#new_job_modal form") |> render_submit(%{"queue" => %{"job_id" => "#{allowed.id}"}})

      refute has_element?(page, "#new_job_modal")
      assert [%{job_id: job_id, status: "unassigned", type: "user", user_id: user_id}] = QueuedItems.list(%{})
      assert job_id == allowed.id
      assert user_id == user.id
      assert render(page) =~ "backup"
    end

    test "a crafted job_id outside the user's roles is not queued", %{conn: conn, other: other} do
      {_view, page} = open_page(conn, "task_automation_controller,home")
      render_click(page, "add_new")
      page |> element("#new_job_modal form") |> render_submit(%{"queue" => %{"job_id" => "#{other.id}"}})

      assert QueuedItems.list(%{}) == []
    end

    test "items queued elsewhere appear live", %{conn: conn, allowed: job} do
      {_view, page} = open_page(conn, "task_automation_controller,home")
      q = queue!(job, "unassigned")
      assert has_element?(page, "td", ~r/^#{q.id}$/)
    end

    test "status updates show live", %{conn: conn, allowed: job} do
      q = queue!(job, "waiting")
      {_view, page} = open_page(conn, "task_automation_controller,home")
      assert render(page) =~ "WAITING"

      {:ok, _} = QueuedItems.create_or_update(q, %{status: "running", machine_id: machine!().id})
      html = render(page)
      assert html =~ "RUNNING"
      assert html =~ "worker1"
    end

    test "completed jobs page does not pick up open items on a live update", %{conn: conn, allowed: job} do
      queue!(job, "completed")
      {_view, page} = open_page(conn, "task_automation_controller,completed_jobs")
      waiting = queue!(job, "unassigned")

      QueuedItems.update()
      refute has_element?(page, "td", ~r/^#{waiting.id}$/)
      refute render(page) =~ "UNASSIGNED"
    end

    test "load more pages 30 at a time", %{conn: conn, allowed: job} do
      items = for _ <- 1..35, do: queue!(job, "unassigned")
      {_view, page} = open_page(conn, "task_automation_controller,home", "&sort=asc|id")

      last = List.last(items)
      refute has_element?(page, "td", ~r/^#{last.id}$/)
      render_click(page, "load_more")
      assert has_element?(page, "td", ~r/^#{last.id}$/)
    end
  end

  describe "manage pages (admin role)" do
    setup %{conn: conn} do
      user = user_fixture(%{first_name: "Tac", last_name: "Admin"})
      tac_role(user, admin: true)
      %{conn: log_in(conn, user), user: user}
    end

    test "machines: create (with errors), toggle active, delete", %{conn: conn} do
      {_view, page} = open_page(conn, "task_automation_controller,manage,machines")
      render_click(page, "add_new")

      html = page |> element("#machines_modal form") |> render_submit(%{"machine" => %{"name" => "m1", "address" => ""}})
      assert html =~ "can&#39;t be blank"

      page |> element("#machines_modal form") |> render_submit(%{"machine" => %{"name" => "m1", "address" => "http://m1"}})
      assert [m] = Machines.list(%{})
      assert render(page) =~ "http://m1"

      render_click(page, "deactivate", %{"id" => "#{m.id}"})
      refute Machines.get(m.id).active
      render_click(page, "activate", %{"id" => "#{m.id}"})
      assert Machines.get(m.id).active

      render_click(page, "delete", %{"id" => "#{m.id}"})
      refute Machines.get(m.id)
      refute render(page) =~ "http://m1"
    end

    test "machines: search by name", %{conn: conn} do
      machine!("alpha")
      machine!("beta")
      {_view, page} = open_page(conn, "task_automation_controller,manage,machines")

      render_click(page, "search", %{"field" => "name"})
      html = render_change(page, "search", %{"search" => %{"field" => "name", "val" => "alp"}})
      assert html =~ "alpha"
      refute html =~ "http://beta"
    end

    test "priorities: create through the modal", %{conn: conn} do
      {_view, page} = open_page(conn, "task_automation_controller,manage,priorities")
      render_click(page, "add_new")
      page |> element("#priorities_modal form") |> render_submit(%{"priority" => %{"name" => "Urgent"}})

      assert [%{name: "Urgent", order: order}] = Priorities.list(%{})
      assert is_integer(order)
      assert render(page) =~ "Urgent"
    end

    test "priorities: moving down swaps the order with the one below", %{conn: conn} do
      {:ok, _low} = Priorities.create_or_update(%Priority{}, %{name: "Low", order: 1})
      {:ok, high} = Priorities.create_or_update(%Priority{}, %{name: "High", order: 2})
      {_view, page} = open_page(conn, "task_automation_controller,manage,priorities")

      html = render(page)
      assert :binary.match(html, "High") < :binary.match(html, "Low")
      # the bottom one has no down button
      assert has_element?(page, "[phx-click='move_dn'][phx-value-id='#{high.id}']")

      render_click(page, "move_dn", %{"id" => "#{high.id}"})
      assert [%{name: "Low", order: 2}, %{name: "High", order: 1}] = Priorities.list(%{})
      html = render(page)
      assert :binary.match(html, "Low") < :binary.match(html, "High")
    end

    test "jobs: create and toggle asynchronous", %{conn: conn} do
      p = priority!()
      {_view, page} = open_page(conn, "task_automation_controller,manage,jobs")
      render_click(page, "add_new")

      html = page |> element("#jobs_modal form") |> render_submit(%{"job" => %{"name" => "", "address" => "/x"}})
      assert html =~ "can&#39;t be blank"

      page |> element("#jobs_modal form") |> render_submit(%{"job" => %{"name" => "nightly", "address" => "/nightly", "priority_id" => "#{p.id}"}})
      assert [job] = Jobs.list(%{})
      assert render(page) =~ "nightly"

      render_click(page, "activate", %{"id" => "#{job.id}", "key" => "asynchronous"})
      assert Jobs.get(job.id).asynchronous
    end

    test "roles: create and delete", %{conn: conn} do
      {_view, page} = open_page(conn, "task_automation_controller,manage,roles")
      render_click(page, "add_new")
      page |> element("#new_role_modal form") |> render_submit(%{"role" => %{"name" => "Operators", "description" => "ops"}})

      role = Enum.find(Roles.list(%{}), &(&1.name == "Operators"))
      assert role
      assert render(page) =~ "Operators"

      render_click(page, "delete", %{"id" => "#{role.id}"})
      refute Roles.get(role.id)
      refute render(page) =~ "Operators"
    end

    test "users: lists active users", %{conn: conn} do
      user_fixture(%{first_name: "Visible"})
      user_fixture(%{first_name: "Retired", active: false})
      {_view, page} = open_page(conn, "task_automation_controller,manage,users")

      html = render(page)
      assert html =~ "Visible"
      refute html =~ "Retired"
    end

    test "users: clicking a row does not crash", %{conn: conn} do
      other = user_fixture(%{first_name: "Clicky"})
      {_view, page} = open_page(conn, "task_automation_controller,manage,users")

      render_click(page, "edit", %{"id" => "#{other.id}"})
      assert render(page) =~ "Clicky"
    end
  end
end
