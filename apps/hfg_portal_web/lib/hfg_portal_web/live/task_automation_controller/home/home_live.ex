defmodule HfgPortalWeb.TaskAutomationController.Home.HomeLive do
  use HfgPortalWeb, :live_view

  alias TaskAutomationController.{
    QueuedItems,
    Jobs.Types,
    Jobs.Statuses,
  }

  alias HfgPortalWeb.TaskAutomationController.Home.Modals.{
    AddJob,
  }

  @preload [:machine, job: :priority]

  defp fetch_queued_items(socket) do
    %{ 
      queued_items:   queued_items,
      page:           page,
      per_page:       per_page,
      search_stack:   search_stack,
      sort_stack:     sort_stack,
      current_user:   %{id: user_id},
      complete:       complete,
    } = socket.assigns

    socket
    |> assign(:queued_items, queued_items ++ QueuedItems.list(%{
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      preload:      @preload,
      user_id:      user_id,
      complete:     complete,
    }))
  end
  defp reload_items(socket), do: socket |> assign(:queued_items, []) |> fetch_queued_items()

  defp fetch_machines(socket) do
    socket
    |> assign(:machines, TaskAutomationController.Machines.list(%{active: true}))
  end

  defp fetch_jobs(socket) do
    socket
    |> assign(:jobs, TaskAutomationController.Jobs.list(%{active: true}))
  end

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    AddJob,
      changeset: QueuedItems.new_changeset(),
      user:      user
    } | modal_stack])
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      QueuedItems.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Task Automation Controller", "Home")
    |> assign(:complete,       false)
    |> assign(:page,           0)
    |> assign(:per_page,       30)
    |> assign(:queued_items,   [])
    |> assign(:modal_stack,    [])
    |> assign(:search_map,     %{}) # search map is for the search form
    |> assign(:search_stack,   [])  # search stack is the data for all the search fields
    |> assign(:sort_stack,     [])  # sort stack is the data for all the sort fields
    |> assign(:session,        %{}) # session is kept so that the session can be updated
    |> handle_params(session)       # here session is the second argument to mount
    |> fetch_machines()
    |> fetch_jobs()
    |> fetch_queued_items()
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
    |> assign(:complete, String.contains?(page, "completed_jobs"))
    |> assign(:session, Map.put(stored_session, "page", page))
    |> handle_params(session |> Map.delete("page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "admin", admin))
    |> handle_params(session |> Map.delete("admin"))
  end

  #defp handle_params(socket, %{"complete" => complete} = session) do
  #  %{session: stored_session} = socket.assigns
  #  socket
  #  |> assign(:session, Map.put(stored_session, "complete", complete))
  #  |> assign(:complete, complete == "true")
  #  |> handle_params(session |> Map.delete("complete"))
  #end
  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:queued_item, :updated], _}, socket) do 
    %{
      queued_items: queued_items,
      per_page:     per_page,
      #search_stack: search_stack,
      sort_stack:   sort_stack,
    } = socket.assigns

    queued_items = Enum.map(queued_items, fn x -> QueuedItems.get(x.id) |> QueuedItems.preload(%{preload: @preload}) end)

    new_items = QueuedItems.list(%{
      page:         0,
      per_page:     per_page,
      search_stack: [%HfgPortal.Helpers.Search{field: :status, val: "unassigned"}],
      sort_stack:   sort_stack,
      preload:      @preload,
    })
    |> Enum.filter(fn x -> !Enum.any?(queued_items, &(&1.id == x.id)) end)

    socket
    |> assign(:queued_items, queued_items ++ new_items)
    |> res()
  end
  @impl true 
  def handle_info({[:queued_item, :created], item}, socket) do 
    socket 
    |> assign(:queued_items, socket.assigns.queued_items ++ [item |> QueuedItems.preload(%{preload: @preload})])
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
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_queued_items()
    |> res()
  end

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

