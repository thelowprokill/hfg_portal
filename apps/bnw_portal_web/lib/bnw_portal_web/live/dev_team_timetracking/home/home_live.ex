defmodule BnwPortalWeb.DevTeamTimetracking.Home.HomeLive do
  use BnwPortalWeb, :live_view

  alias BnwPortalWeb.DevTeamTimetracking.Home.Modals.{
    ChangeTimesheets
  }

  alias DevTeamTimetracking.{
    Capacities,
    Projects,
    FavoriteProjects,
    FixedProjects,
    Repo,
  }

  defp save_capacity(socket, params, key) do
    changeset = 
      socket.assigns
      |> Map.get(key)
      |> Map.get(:data)
      |> Capacities.change(params)
      |> Map.put(:action, :insert)

    cond do
      changeset.valid? ->
        changeset.data |> Capacities.create_or_update(params)
        |> case do
          {:ok, data} -> socket |> assign(key, data |> Capacities.change())
          {:error, changeset} -> socket |> assign(key, changeset)
        end
      true -> socket
    end
  end

  defp fetch_capacity(socket) do
    %{current_user: %{id: user_id}} = socket.assigns

    this_monday = Date.utc_today() |> Date.beginning_of_week()
    prev_monday = Date.add(this_monday, -7)
    next_monday = Date.add(this_monday, 7)

    capacities = Capacities.list(%{user_id: user_id, dates: [prev_monday, this_monday, next_monday]})

    socket 
    |> assign(:prev_monday, prev_monday)
    |> assign(:this_monday, this_monday)
    |> assign(:next_monday, next_monday)
    |> assign(:cap_prev, capacities |> Enum.find(Capacities.new(), &(&1.monday == prev_monday)) |> Capacities.change())
    |> assign(:cap_this, capacities |> Enum.find(Capacities.new(), &(&1.monday == this_monday)) |> Capacities.change())
    |> assign(:cap_next, capacities |> Enum.find(Capacities.new(), &(&1.monday == next_monday)) |> Capacities.change())
  end

  defp fetch_favorite_projects(socket) do
    %{
      search_stack:      search_stack,
      sort_stack:        sort_stack,
      current_user:      %{id: user_id}
    } = socket.assigns

    socket |> assign(:favorite_projects, Projects.list(
      %{
        favorite:     true,
        user_id:      user_id,
        search_stack: search_stack,
        sort_stack:   sort_stack,
      }
    ))
  end
  defp fetch_fixed_projects(socket) do
    %{
      search_stack:   search_stack,
      sort_stack:     sort_stack
    } = socket.assigns

    socket |> assign(:fixed_projects, FixedProjects.list(
      %{
        search_stack: search_stack,
        sort_stack:   sort_stack,
      }
    ))
  end
  defp fetch_projects(socket) do
    %{
      page:         page,
      per_page:     per_page,
      projects:     projects,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      current_user: %{id: user_id}
    } = socket.assigns

    socket |> assign(:projects, projects ++ Projects.list(
      %{
        favorite:     false,
        user_id:      user_id,
        page:         page,
        per_page:     per_page,
        search_stack: search_stack,
        sort_stack:   sort_stack,
      }
    ))
  end

  defp reload_items(socket), do: socket |> assign(:projects, []) |> fetch_fixed_projects() |> fetch_favorite_projects() |> fetch_projects()
  #defp fetch_reports(socket), do: socket |> assign(:reports, Reports.list(%{active: true}))

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :fixed_timesheets, id) when not is_nil(id) do
    %{
      fixed_projects: projects,
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :timesheets,
      id:        :timesheets,
      module:    ChangeTimesheets,
      live:      true,
      user:      user,
      opts:      %{
        fixed_project_id: id,
        project_name:     Enum.find(projects, &(&1.id == id)) |> Map.get(:name),
        user_id:          user.id
      }
    } | modal_stack])
  end

  defp set_modal(socket, :timesheets, id) when not is_nil(id) do
    %{
      projects:          projects,
      favorite_projects: favorite_projects,
      modal_stack:       modal_stack,
      current_user:      user
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :timesheets,
      id:        :timesheets,
      module:    ChangeTimesheets,
      live:      true,
      user:      user,
      opts:      %{
        project_id:   id,
        project_name: Enum.find(projects, Enum.find(favorite_projects, &(&1.id == id)), &(&1.id == id)) |> Map.get(:name),
        user_id:      user.id
      }
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
      FavoriteProjects.subscribe()
      #Reports.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Dev Team Timetracking", "Home")
    #|> fetch_user_role()
    |> assign(:session,       %{})
    |> assign(:page,          0)
    |> assign(:per_page,      50)
    |> assign(:favorite_projects, [])
    |> assign(:fixed_projects,[])
    |> assign(:projects,      [])
    |> assign(:reports,       [])
    |> assign(:modal_stack,   [])
    |> assign(:capacity,      %{})
    |> assign(:search_map,    %{})
    |> assign(:search_stack,  [])
    |> assign(:sort_stack,    [])
    |> handle_params(session)
    |> fetch_favorite_projects()
    |> fetch_fixed_projects()
    |> fetch_projects()
    |> fetch_capacity()
    #|> fetch_reports()
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
  def handle_info({[:favorite_project, :created], favorite_project}, socket) when favorite_project.user_id == socket.assigns.current_user.id do
    socket
    |> assign(:projects, Enum.reject(socket.assigns.projects, &(&1.id == favorite_project.project_id)))
    |> fetch_favorite_projects()
    |> res()
  end
  @impl true
  def handle_info({[:favorite_project, :deleted], favorite_project}, socket) when favorite_project.user_id == socket.assigns.current_user.id do
    socket
    |> assign(:projects, [favorite_project.project_id |> Projects.get | socket.assigns.projects])
    |> fetch_favorite_projects()
    |> res()
  end
  @impl true
  def handle_info({[:favorite_project, _], _}, socket), do: socket |> res()

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
  def handle_event("add_favorite", %{"id" => id}, socket) do 
    FavoriteProjects.set(id, socket.assigns.current_user.id, true)
    socket |> res()
  end
  @impl true
  def handle_event("remove_favorite", %{"id" => id}, socket) do 
    FavoriteProjects.set(id, socket.assigns.current_user.id, false)
    socket |> res()
  end

  @impl true
  def handle_event("cap_prev", %{"cap_prev" => params}, socket), do: save_capacity(socket, params, :cap_prev) |> res()
  @impl true
  def handle_event("cap_this", %{"cap_this" => params}, socket), do: save_capacity(socket, params, :cap_this) |> res()
  @impl true
  def handle_event("cap_next", %{"cap_next" => params}, socket), do: save_capacity(socket, params, :cap_next) |> res()

  @impl true
  def handle_event("add_new", _, socket), do: socket |> set_modal(:new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: socket |> set_modal(:edit, id |> String.to_integer) |> res()

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
    |> fetch_projects()
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
