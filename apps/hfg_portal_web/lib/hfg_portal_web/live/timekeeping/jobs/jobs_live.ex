defmodule HfgPortalWeb.Timekeeping.Jobs.JobsLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Timekeeping.Jobs.Modals.{ChangeJob, LogTime}

  alias Timekeeping.{Jobs, TimeEntries}

  defp fetch_jobs(socket) do
    %{
      page:         page,
      per_page:     per_page,
      jobs:         jobs,
      search_stack: search_stack,
      sort_stack:   sort_stack,
    } = socket.assigns

    fetched = Jobs.list(%{
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack,
    })

    socket |> assign(:jobs, jobs ++ fetched)
  end

  defp reload_items(socket), do: socket |> assign(:jobs, []) |> assign(:page, 0) |> fetch_jobs()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{modal_stack: modal_stack, current_user: user} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeJob,
      changeset: Jobs.new_changeset(%{user_id: user.id}),
      live:      false,
      user:      user,
      opts:      %{}
    } | modal_stack])
  end

  defp set_modal(socket, :edit, id) when not is_nil(id) do
    %{modal_stack: modal_stack, current_user: user} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :edit,
      id:        :edit,
      module:    ChangeJob,
      changeset: Jobs.get(id) |> Jobs.change(),
      live:      false,
      user:      user,
      opts:      %{}
    } | modal_stack])
  end

  defp set_modal(socket, :log_time, id) when not is_nil(id) do
    %{modal_stack: modal_stack, current_user: user} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :log_time,
      id:        :log_time,
      module:    LogTime,
      changeset: nil,
      live:      false,
      user:      user,
      opts:      %{job: Jobs.get(id)}
    } | modal_stack])
  end

  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Jobs.subscribe()
      TimeEntries.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Timekeeping", "Jobs")
    |> assign(:session,       %{})
    |> assign(:page,          0)
    |> assign(:per_page,      50)
    |> assign(:jobs,          [])
    |> assign(:open_job_starts, TimeEntries.open_job_starts())
    |> assign(:modal_stack,   [])
    |> assign(:search_map,    %{})
    |> assign(:search_stack,  [])
    |> assign(:sort_stack,    [])
    |> handle_params(session)
    |> fetch_jobs()
    |> res(:ok)
  end

  defp handle_params(socket, %{"app" => app} = session) do
    %{session: stored} = socket.assigns
    socket |> assign(:session, Map.put(stored, "app", app)) |> handle_params(Map.delete(session, "app"))
  end
  defp handle_params(socket, %{"page" => page} = session) do
    %{session: stored} = socket.assigns
    socket |> assign(:session, Map.put(stored, "page", page)) |> handle_params(Map.delete(session, "page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do
    %{session: stored} = socket.assigns
    socket |> assign(:session, Map.put(stored, "admin", admin)) |> handle_params(Map.delete(session, "admin"))
  end
  defp handle_params(socket, %{"search" => _} = session) do
    socket |> search_handle_params(session) |> handle_params(Map.delete(session, "search"))
  end
  defp handle_params(socket, %{"sort" => _} = session) do
    socket |> sort_handle_params(session) |> handle_params(Map.delete(session, "sort"))
  end
  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:job, :created], job}, socket) do
    socket |> assign(:jobs, [job | socket.assigns.jobs]) |> res()
  end
  @impl true
  def handle_info({[:job, :updated], job}, socket) do
    socket |> assign(:jobs, Enum.map(socket.assigns.jobs, &(if &1.id == job.id, do: job, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:job, :deleted], job}, socket) do
    socket |> assign(:jobs, Enum.reject(socket.assigns.jobs, &(&1.id == job.id))) |> res()
  end

  @impl true
  def handle_info({[:time_entry, :created], entry}, socket), do: socket |> put_open_job(entry) |> res()
  @impl true
  def handle_info({[:time_entry, :updated], entry}, socket), do: socket |> put_open_job(entry) |> res()

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  defp put_open_job(socket, %{job_id: job_id, end_time: nil, start_time: start_time}) do
    assign(socket, :open_job_starts, Map.put(socket.assigns.open_job_starts, job_id, start_time))
  end
  defp put_open_job(socket, %{job_id: job_id}) do
    assign(socket, :open_job_starts, Map.delete(socket.assigns.open_job_starts, job_id))
  end

  @impl true
  def handle_event("add_new", _, socket),                      do: socket |> set_modal(:new) |> res()
  @impl true
  def handle_event("edit", %{"id" => id}, socket),             do: socket |> set_modal(:edit, String.to_integer(id)) |> res()
  @impl true
  def handle_event("log_time", %{"id" => id}, socket),         do: socket |> set_modal(:log_time, String.to_integer(id)) |> res()
  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    Jobs.delete(String.to_integer(id))
    socket |> res()
  end
  @impl true
  def handle_event("cancel", _, socket),                       do: socket |> set_modal() |> res()
  @impl true
  def handle_event("load_more", _, socket) do
    socket |> assign(:page, socket.assigns.page + 1) |> fetch_jobs() |> res()
  end
  @impl true
  def handle_event("sort", params, socket),                    do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket), do: socket |> search(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"field" => _} = params, socket),  do: socket |> search(params) |> res()
  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket), do: socket |> search_reset_filter(field) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", _, socket),                do: socket |> search_reset_filter() |> reload_items() |> res()
  @impl true
  def handle_event("hide_filter", _, socket),                  do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
