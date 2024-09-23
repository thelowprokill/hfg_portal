defmodule BnwPortalWeb.DevTeamTimetracking.FixedProjects.FixedProjectsLive do
  use BnwPortalWeb, :live_view

  alias BnwPortalWeb.DevTeamTimetracking.FixedProjects.Modals.{
    ChangeFixedProjects,
  }

  alias DevTeamTimetracking.{
    FixedProjects,
    Repo,
  }

  defp fetch_fixed_projects(socket) do
    %{
      page:               page,
      per_page:           per_page,
      fixed_projects:     fixed_projects,
      search_stack:       search_stack,
      sort_stack:         sort_stack
    } = socket.assigns

    socket |> assign(:fixed_projects, fixed_projects ++ FixedProjects.list(
      %{
        page:         page,
        per_page:     per_page,
        search_stack: search_stack,
        sort_stack:   sort_stack,
        preload:      [timesheets: [:user]],
      }
    ))
  end

  defp reload_items(socket), do: socket |> assign(:projects, []) |> fetch_fixed_projects()
  #defp fetch_reports(socket), do: socket |> assign(:reports, Reports.list(%{active: true}))

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, id) do
    %{
      current_user: user,
      modal_stack: modal_stack
    } = socket.assigns

    changeset = FixedProjects.new_changeset()

    socket |> assign(:modal_stack, [%Modal{
      id: id,
      modal:     :edit,
      module:    ChangeFixedProjects,
      changeset: changeset,
      user:      user,
      opts:      %{user_id: user.id}
    } | modal_stack])
  end
  defp set_modal(socket, :edit, id) do
    %{
      current_user: user,
      modal_stack: modal_stack
    } = socket.assigns

    changeset = 
      id
      |> FixedProjects.get()
      |> case do
        nil  -> FixedProjects.new_changeset()
        user -> FixedProjects.change(user)
      end

    socket |> assign(:modal_stack, [%Modal{
      id: id,
      modal:     :edit,
      module:    ChangeFixedProjects,
      changeset: changeset,
      user:      user,
      opts:      %{user_id: user.id}
    } | modal_stack])
  end

  defp set_modal(socket, :reports, id) when not is_nil(id) do
    %{ 
      modal_stack: modal_stack,
      reports:     reports
    } = socket.assigns
    socket
    |> assign(:modal_stack, [%Modal{
      modal:  :report,
      id:     :report,
      opts:   %{report: Enum.find(reports, &(&1.id == id)) |> Reports.decorate()},
    } | modal_stack])
  end

  defp set_modal(socket, :reports, _) do
    %{ 
      modal_stack: modal_stack,
      reports:     reports
    } = socket.assigns

    socket
    |> assign(:modal_stack, 
      cond do
        length(reports) == 1 ->
          [%Modal{
            modal:  :report,
            id:     :report,
            opts:   %{report: Enum.at(reports, 0) |> Reports.decorate()},
          } | modal_stack]
        length(reports) > 1 ->
          [ %Modal{
            modal:  :pick_reports,
            id:     :pick_reports,
            module: nil
          } | modal_stack]
        true -> 
          modal_stack
      end)
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      FixedProjects.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Dev Team Timetracking", "Home")
    |> assign(:session,       %{})
    |> assign(:page,          0)
    |> assign(:per_page,      50)
    |> assign(:projects,      [])
    |> assign(:fixed_projects,[])
    |> assign(:reports,       [])
    |> assign(:modal_stack,   [])
    |> assign(:search_map,    %{})
    |> assign(:search_stack,  [])
    |> assign(:sort_stack,    [])
    |> handle_params(session)
    |> fetch_fixed_projects()
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
  def handle_info({[:fixed_project, :created], fixed_project}, socket) do
    socket
    |> assign(:fixed_projects, [fixed_project | socket.assigns.fixed_projects])
    |> res()
  end
  @impl true
  def handle_info({[:fixed_project, :updated], fixed_project}, socket) do
    %{fixed_projects: fixed_projects} = socket.assigns
    socket
    |> assign(:fixed_projects, Enum.map(fixed_projects, &(if &1.id == fixed_project.id, do: fixed_project, else: &1)))
    |> res()
  end
  @impl true
  def handle_info({[:fixed_project, :deleted], fixed_project}, socket) do
    socket
    |> assign(:fixed_projects, Enum.reject(socket.assigns.fixed_projects, &(&1.id == fixed_project.id)))
    |> res()
  end

  @impl true
  def handle_info({[:report, :created], report}, socket) do
    socket
    |> assign(:reports, [report | socket.assigns.reports])
    |> res()
  end
  @impl true
  def handle_info({[:report, :updated], report}, socket) do
    %{reports: reports} = socket.assigns
    socket
    |> assign(:reports, cond do
      Enum.any?(reports, &(&1.id == report.id)) -> Enum.map(reports, &(if &1.id == report.id, do: report, else: &1))
      true -> [report | reports]
    end |> Enum.filter(&(&1.active)))
    |> res()
  end
  @impl true
  def handle_info({[:report, :deleted], report}, socket) do
    socket
    |> assign(:reports, Enum.reject(socket.assigns.reports, &(&1.id == report.id)))
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
  def handle_event("timesheets", %{"id" => id}, socket), do: socket |> set_modal(:timesheets, id |> String.to_integer) |> res()

  @impl true
  def handle_event("fixed_timesheets", %{"id" => id}, socket), do: socket |> set_modal(:fixed_timesheets, id |> String.to_integer) |> res()

  @impl true
  def handle_event("add_new", _, socket), do: socket |> set_modal(:new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: socket |> set_modal(:edit, id |> String.to_integer) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do 
    id |> String.to_integer |> FixedProjects.delete()
    socket |> res()
  end

  @impl true
  def handle_event("reports", %{"id" => id}, socket), do: socket |> set_modal(:reports, id |> String.to_integer) |> res()

  @impl true
  def handle_event("reports", _, socket), do: socket |> set_modal(:reports) |> res()

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_fixed_projects()
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
