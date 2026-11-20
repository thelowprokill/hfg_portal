# Hosts one of the Jobs page's modal components on its own, the way JobsLive renders it, so the
# modals can be tested on their own.
defmodule HfgPortalWeb.Timekeeping.JobsLiveTest.Host do
  alias Timekeeping.Jobs
  alias HfgPortalWeb.Timekeeping.Jobs.Modals.{ChangeJob, LogTime}

  use Phoenix.LiveView

  def mount(_params, %{"component" => component, "user_id" => user_id} = session, socket) do
    user = HfgPortal.Repo.get!(HfgPortal.Accounts.User, user_id)

    modal =
      case component do
        ChangeJob ->
          changeset = if id = session["job_id"], do: Jobs.change(Jobs.get(id)), else: Jobs.new_changeset(%{user_id: user.id})
          %HfgPortal.Helpers.Modal{modal: :new, id: if(session["job_id"], do: :edit, else: :new), module: ChangeJob, changeset: changeset, user: user}

        LogTime ->
          %HfgPortal.Helpers.Modal{modal: :log_time, id: :log_time, module: LogTime, user: user, opts: %{job: Jobs.get(session["job_id"])}}
      end

    {:ok, assign(socket, modal: modal, closed: false)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <%= if @closed do %>closed<% else %>
        <.live_component module={@modal.module} id="modal" modal={@modal} />
      <% end %>
    </div>
    """
  end

  def handle_info(:cancel, socket), do: {:noreply, assign(socket, :closed, true)}
  def handle_event("cancel", _, socket), do: {:noreply, assign(socket, :closed, true)}
end


defmodule HfgPortalWeb.Timekeeping.JobsLiveTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortalWeb.LiveFixtures2

  alias Timekeeping.{Jobs, TimeEntries, UserRoles}
  alias HfgPortalWeb.Timekeeping.Jobs.Modals.{ChangeJob, LogTime}
  alias HfgPortalWeb.Timekeeping.JobsLiveTest.Host

  @page "timekeeping,home"

  defp job_fixture(user, attrs \\ %{}) do
    {:ok, job} = Jobs.create_or_update(Jobs.new(), Enum.into(attrs, %{user_id: user.id, name: "Job #{System.unique_integer([:positive])}"}))
    job
  end

  defp entry_fixture(job, start_time, end_time) do
    {:ok, e} = TimeEntries.create_or_update(TimeEntries.new(), %{job_id: job.id, start_time: start_time, end_time: end_time})
    e
  end

  defp host(conn, component, user, job \\ nil) do
    session = %{"component" => component, "user_id" => user.id}
    session = if job, do: Map.put(session, "job_id", job.id), else: session
    {:ok, view, _html} = live_isolated(conn, Host, session: session)
    view
  end

  setup %{conn: conn} do
    user = user_with_role(UserRoles, "Edit")
    %{conn: log_in_user(conn, user), user: user}
  end

  describe "authorization" do
    test "None or no role gets the portal home", %{conn: conn} do
      for user <- [user_with_role(UserRoles, "None"), HfgPortal.AccountsFixtures.user_fixture()] do
        assert page_module(log_in_user(conn, user), @page) == HfgPortalWeb.Home.HomeLive
      end
    end

    test "Edit and Admin roles open the Jobs page", %{conn: conn} do
      for role <- ~w(Edit Admin) do
        conn = log_in_user(conn, user_with_role(UserRoles, role))
        assert page_module(conn, @page) == HfgPortalWeb.Timekeeping.Jobs.JobsLive
      end
    end

    test "a user only sees their own jobs", %{conn: conn, user: user} do
      job_fixture(user, %{name: "Mine"})
      job_fixture(HfgPortal.AccountsFixtures.user_fixture(), %{name: "Someone else's"})

      {_view, page} = open_page(conn, @page)
      html = render(page)
      assert html =~ "Mine"
      refute html =~ "Someone else"
    end
  end

  describe "jobs page" do

    test "lists jobs with client, rate and total logged time; running jobs are marked", %{conn: conn, user: user} do
      job = job_fixture(user, %{name: "Website", client: "Acme", hourly_rate: Decimal.new("50.00")})
      entry_fixture(job, ~U[2026-01-01 10:00:00Z], ~U[2026-01-01 11:30:00Z])
      running = job_fixture(user, %{name: "Running one"})
      TimeEntries.start_now(running.id, user.id)

      {_view, page} = open_page(conn, @page)
      html = render(page)
      assert html =~ "Acme"
      assert html =~ "$50.00/hr"
      assert html =~ "01:30:00"
      assert has_element?(page, "#jobs_elapsed_#{running.id}")
      refute has_element?(page, "#jobs_elapsed_#{job.id}")
    end

    test "creating, editing and deleting a job", %{conn: conn, user: user} do
      {_view, page} = open_page(conn, @page)

      render_click(page, "add_new", %{})
      page |> form("#job form", %{"job" => %{"name" => "Consulting"}}) |> render_submit()
      assert [job] = Jobs.list(%{})
      assert job.user_id == user.id
      assert render(page) =~ "Consulting"

      render_click(page, "edit", %{"id" => "#{job.id}"})
      page |> form("#job form", %{"job" => %{"name" => "Advising"}}) |> render_submit()
      assert render(page) =~ "Advising"

      render_click(page, "delete", %{"id" => "#{job.id}"})
      assert Jobs.get(job.id) == nil
      refute render(page) =~ "Advising"
    end

    test "time logged elsewhere updates the total live", %{conn: conn, user: user} do
      job = job_fixture(user)
      {_view, page} = open_page(conn, @page)

      entry_fixture(job, ~U[2026-01-01 10:00:00Z], ~U[2026-01-01 10:45:00Z])
      assert render(page) =~ "00:45:00"
    end

    test "search, sort and load more", %{conn: conn, user: user} do
      for n <- 1..52, do: job_fixture(user, %{name: "Job #{String.pad_leading("#{n}", 2, "0")}"})
      {_view, page} = open_page(conn, @page)

      assert count(page, ~s(tr[phx-click="log_time"])) == 50
      render_click(page, "load_more", %{})
      assert count(page, ~s(tr[phx-click="log_time"])) == 52

      render_click(page, "search", %{"field" => "name"})
      render_change(page, "search", %{"search" => %{"field" => "name", "val" => "Job 07"}})
      assert count(page, ~s(tr[phx-click="log_time"])) == 1
    end

    test "clicking a job opens the log time modal", %{conn: conn, user: user} do
      job = job_fixture(user, %{name: "Clickable"})
      {_view, page} = open_page(conn, @page)
      render_click(page, "log_time", %{"id" => "#{job.id}"})
      assert has_element?(page, "#log_time", "Clickable")
    end
  end

  describe "job modal" do
    test "name is required", %{conn: conn, user: user} do
      view = host(conn, ChangeJob, user)

      html = view |> form("#job form", %{"job" => %{"name" => ""}}) |> render_change()
      assert html =~ "can&#39;t be blank"

      view |> form("#job form", %{"job" => %{"name" => ""}}) |> render_submit()
      assert Jobs.list(%{}) == []
      refute render(view) =~ "closed"
    end

    test "a new job is saved for the current user", %{conn: conn, user: user} do
      view = host(conn, ChangeJob, user)

      view |> form("#job form", %{"job" => %{"name" => "Garden", "client" => "Neighbour", "hourly_rate" => "25.50"}}) |> render_submit()

      assert [job] = Jobs.list(%{})
      assert %{name: "Garden", client: "Neighbour", user_id: user_id} = job
      assert user_id == user.id
      assert Decimal.equal?(job.hourly_rate, Decimal.new("25.50"))
      assert render(view) =~ "closed"
    end

    test "editing a job", %{conn: conn, user: user} do
      job = job_fixture(user, %{name: "Before"})
      view = host(conn, ChangeJob, user, job)

      view |> form("#job form", %{"job" => %{"name" => "After"}}) |> render_submit()
      assert Jobs.get(job.id).name == "After"
    end
  end

  describe "log time modal" do
    setup %{conn: conn, user: user} do
      job = job_fixture(user, %{name: "Painting"})
      %{job: job, view: host(conn, LogTime, user, job)}
    end

    test "starts empty", %{view: view} do
      html = render(view)
      assert html =~ "Painting"
      assert html =~ "Not currently running"
      assert html =~ "No time entries yet"
      assert html =~ "00:00:00"
    end

    test "start then stop a timer", %{job: job, view: view} do
      view |> element(~s(button[phx-click="start"])) |> render_click()
      assert [%{end_time: nil} = entry] = TimeEntries.list_for_job(job.id)
      assert has_element?(view, ~s(button[phx-click="stop"]))
      assert render(view) =~ "Running"

      view |> element(~s(button[phx-click="stop"])) |> render_click()
      assert TimeEntries.get(entry.id).end_time
      assert render(view) =~ "Not currently running"
    end

    test "starting a job stops the user's other running timer", %{conn: conn, user: user, job: job} do
      other = job_fixture(user)
      {:ok, running} = TimeEntries.start_now(other.id, user.id)

      view = host(conn, LogTime, user, job)
      view |> element(~s(button[phx-click="start"])) |> render_click()

      assert TimeEntries.get(running.id).end_time
      assert TimeEntries.get_open_for_job(job.id)
    end

    test "adding an entry by hand updates history and total", %{job: job, view: view} do
      view
      |> form("#log_time form")
      |> render_submit(%{"time_entry" => %{"start_time" => "2026-01-01T09:00:00Z", "end_time" => "2026-01-01T11:30:00Z"}})

      assert [entry] = TimeEntries.list_for_job(job.id)
      assert entry.start_time == ~U[2026-01-01 09:00:00Z]
      html = render(view)
      assert html =~ "2h 30m"
      assert html =~ "02:30:00"
    end

    test "end before start is rejected with a message", %{job: job, view: view} do
      html =
        view
        |> form("#log_time form")
        |> render_submit(%{"time_entry" => %{"start_time" => "2026-01-01T11:00:00Z", "end_time" => "2026-01-01T10:00:00Z"}})

      assert html =~ "end_time: must be after the start time"
      assert TimeEntries.list_for_job(job.id) == []
    end

    test "editing and deleting an entry", %{conn: conn, user: user, job: job} do
      entry = entry_fixture(job, ~U[2026-01-01 09:00:00Z], ~U[2026-01-01 10:00:00Z])
      view = host(conn, LogTime, user, job)

      view |> element(~s(button[phx-click="edit_entry"][phx-value-id="#{entry.id}"])) |> render_click()
      assert render(view) =~ "Update Entry"

      view
      |> form("#log_time form")
      |> render_submit(%{"time_entry" => %{"end_time" => "2026-01-01T12:00:00Z"}})

      assert TimeEntries.get(entry.id).end_time == ~U[2026-01-01 12:00:00Z]
      assert render(view) =~ "3h 00m"

      view |> element(~s(button[phx-click="delete_entry"][phx-value-id="#{entry.id}"])) |> render_click()
      assert TimeEntries.get(entry.id) == nil
      assert render(view) =~ "No time entries yet"
    end

    test "cancel closes it", %{view: view} do
      render_click(view, "cancel", %{})
      assert render(view) =~ "closed"
    end
  end
end
