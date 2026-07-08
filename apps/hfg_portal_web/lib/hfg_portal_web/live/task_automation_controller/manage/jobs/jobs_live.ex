defmodule HfgPortalWeb.TaskAutomationController.Manage.Jobs.JobsLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.TaskAutomationController.Manage.Jobs.Modals.{
    ChangeJob,
  }

  alias TaskAutomationController.{
    Jobs,
  }

  @preload [:priority]

  defp fetch_jobs(socket) do
    %{ 
      jobs:          jobs,
      page:          page,
      per_page:      per_page,
      search_stack:  search_stack,
      sort_stack:    sort_stack,
      current_user:  %{id: user_id},
    } = socket.assigns

    socket
    |> assign(:jobs, jobs ++ Jobs.list(%{
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      preload:      @preload,
      user_id:      user_id
    }))
  end
  defp reload_items(socket), do: socket |> assign(:jobs, []) |> fetch_jobs()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeJob,
      changeset: Jobs.new_changeset(),
      user:      user
    } | modal_stack])
  end
  defp set_modal(socket, :edit, id) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns
    socket |> assign(:modal_stack, [%Modal{
      modal: :edit,
      id:    :edit,
      module: ChangeJob,
      changeset: id |> Jobs.get() |> Jobs.change(),
      user: user
    } | modal_stack])
  end
  defp set_modal(socket, :schedule, id) do
    %{
      modal_stack:  modal_stack,
      current_user: user,
      jobs:         jobs,
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal: :schedule,
      id:    :schedule,
      live:  :true,
      module: ScheduleJob,
      user: user,
      opts: %{
        job:     Enum.find(jobs, &(&1.id == id)),
        user_id: user.id
      }
    } | modal_stack])
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Jobs.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Task Automation Controller", "Jobs")
    |> assign(:page,           0)
    |> assign(:per_page,       30)
    |> assign(:jobs,           [])
    |> assign(:modal_stack,    [])
    |> assign(:search_map,     %{}) # search map is for the search form
    |> assign(:search_stack,   [])  # search stack is the data for all the search fields
    |> assign(:sort_stack,     [])  # sort stack is the data for all the sort fields
    |> assign(:session,        %{}) # session is kept so that the session can be updated
    |> handle_params(session)       # here session is the second argument to mount
    |> fetch_jobs()
    |> res(:ok)
  end

  # add these handle_params functions
  # note that handle_params is not the normal callback function, so this can be changed as needed
  defp handle_params(socket, %{"search" => _search} = session) do 
    socket
    |> search_handle_params(session)
    |> handle_params(session |> Map.delete("search"))
  end
  defp handle_params(socket, %{"sort" => _sort} = session) do 
    socket
    |> sort_handle_params(session)
    |> handle_params(session |> Map.delete("sort"))
  end

  # these are required to keep on the page, and admin
  defp handle_params(socket, %{"page" => page} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "page", page))
    |> handle_params(session |> Map.delete("page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "admin", admin))
    |> handle_params(session |> Map.delete("admin"))
  end
  defp handle_params(socket, _session), do: socket



  @impl true
  def handle_info({[:job, :created], job}, socket) do
    socket
    |> assign(:jobs, [job |> Jobs.preload(%{preload: @preload}) | socket.assigns.jobs])
    |> res()
  end
  @impl true
  def handle_info({[:job, :updated], job}, socket) do
    socket
    |> assign(:jobs, Enum.map(socket.assigns.jobs, &(if &1.id == job.id, do: job |> Jobs.preload(%{preload: @preload}), else: &1)))
    |> res()
  end
  @impl true
  def handle_info({[:job, :deleted], job}, socket) do
    socket
    |> assign(:jobs, Enum.reject(socket.assigns.jobs, &(&1.id == job.id)))
    |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("add_new", _, socket), do: socket |> set_modal(:new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: socket |> set_modal(:edit, id |> String.to_integer) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do 
    id |> String.to_integer |> Jobs.delete()
    socket |> res()
  end

  @impl true
  def handle_event("deactivate", %{"id" => id, "key" => key}, socket) do
    id |> String.to_integer() |> Jobs.deactivate(String.to_atom(key))
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"id" => id, "key" => key}, socket) do
    id |> String.to_integer() |> Jobs.activate(String.to_atom(key))
    socket |> res()
  end

  @impl true
  def handle_event("deactivate", %{"id" => id}, socket) do
    id |> String.to_integer() |> Jobs.deactivate()
    socket |> res()
  end
  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    id |> String.to_integer() |> Jobs.activate()
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_jobs()
    |> res()
  end

  @impl true
  def handle_event("schedule", %{"id" => id}, socket), do: socket |> set_modal(:schedule, id |> String.to_integer) |> res()

  @impl true
  def handle_event("sort", params, socket), do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket), do: socket |> search_reset_filter(field) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", _, socket), do: socket |> search_reset_filter() |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket), do: socket |> search(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"field" => _} = params, socket), do: search(socket, params) |> res()
  @impl true
  def handle_event("hide_filter", _, socket), do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end

