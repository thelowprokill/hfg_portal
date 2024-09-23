defmodule BnwPortalWeb.ItBudget.Reports.ReportsLive do
  use BnwPortalWeb, :live_view

  alias BnwPortalWeb.ItBudget.Reports.Modals.ChangeReport
  alias ItBudget.Reports

  defp fetch_reports(socket) do
    %{
      page:         page,
      per_page:     per_page,
      reports:      reports,
      search_stack: search_stack,
      sort_stack:   sort_stack
    } = socket.assigns

    socket |> assign(:reports, reports ++ Reports.list(
      %{
        page:         page,
        per_page:     per_page,
        search_stack: search_stack,
        sort_stack:   sort_stack,
      }
    ))
  end
  defp reload_items(socket), do: socket |> assign(:reports, []) |> fetch_reports()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _id) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %{
      modal:     :new,
      id:        :new,
      module:    ChangeReport,
      changeset: Reports.new_changeset(%{year: Date.utc_today().year}),
      user:      user
    }))
  end
  defp set_modal(socket, :edit, id) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %{
      modal:     :edit,
      id:        id,
      module:    ChangeReport,
      changeset: id |> Reports.get() |> Reports.change(),
      user:      user
    }))
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Reports.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Budget", "Reports")
    |> assign(:page,         0)
    |> assign(:per_page,     30)
    |> assign(:reports,      [])
    |> assign(:modal_stack,  [])
    |> assign(:search_map,   %{})
    |> assign(:search_stack, [])
    |> assign(:sort_stack,   [])
    |> assign(:session,      %{})
    |> handle_params(session)
    |> fetch_reports()
    |> res(:ok)
  end

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

  defp handle_params(socket, %{"app" => app} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "app", app))
    |> handle_params(session |> Map.delete("app"))
  end
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
  def handle_info({[:report, :created], report}, socket) do
    socket
    |> assign(:reports, [report | socket.assigns.reports])
    |> res()
  end
  @impl true
  def handle_info({[:report, :updated], report}, socket) do
    socket
    |> assign(:reports, Enum.map(socket.assigns.reports, &(if &1.id == report.id, do: report, else: &1)))
    |> res()
  end
  @impl true
  def handle_info({[:report, :deleted], report}, socket) do
    socket
    |> assign(:reports, Enum.reject(socket.assigns.reports, &(&1.id == report.id)))
    |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("add_new", _, socket), do: set_modal(socket, :new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: set_modal(socket, :edit, id |> String.to_integer) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do  
    id |> String.to_integer |> Reports.delete()
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_reports()
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
