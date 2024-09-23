defmodule BnwPortalWeb.DevTeamTimetracking.Reports.ReportsLive do
  use BnwPortalWeb, :live_view

  alias BnwPortalWeb.DevTeamTimetracking.Users.Modals.{
    ChangeUserRoles,
  }

  alias DevTeamTimetracking.{
    Capacities,
    Timesheets,
    UserRoles,
    Users.Roles,
  }

  defp fetch_users(socket) do
    %{
      page:         page, 
      per_page:     per_page, 
      users:        users,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      timeframe:    timeframe,
      date:         date,
    } = socket.assigns

    socket |> assign(:users, users ++ UserRoles.list(
      %{
        dev_user:     true,
        page:         page, 
        per_page:     per_page, 
        search_stack: search_stack,
        sort_stack:   sort_stack,
        preload:      [capacities: Capacities.capacities_query(timeframe, date), timesheets: Timesheets.timesheets_query(timeframe, date)],#[:project, :fixed_project]],
      }
    ))
  end
  defp reload_items(socket), do: socket |> assign(:users, []) |> fetch_users()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      #UserRoles.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Reports")
    |> assign(:page,         0)
    |> assign(:per_page,     30)
    |> assign(:users,        [])
    |> assign(:changeset,    nil)
    |> assign(:search_map,   %{})
    |> assign(:search_stack, [])
    |> assign(:sort_stack,   [])
    |> assign(:modal_stack,  [])
    |> assign(:session,      %{})
    |> assign(:timeframe,    "week")
    |> assign(:date,         Date.utc_today())
    |> handle_params(session)
    |> fetch_users()
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
  def handle_info({[:dev_team_timetracking, :user_role, :created], user_role}, socket) do
    %{users: users} = socket.assigns

    socket
    |> assign(:users, Enum.map(users, &(if &1.id == user_role.user_id, do: %{%{&1 | user_role: user_role} | role: Roles.get(user_role.role)}, else: &1)))
    |> res()
  end

  @impl true
  def handle_info({[:dev_team_timetracking, :user_role, :updated], user_role}, socket) do
    %{users: users} = socket.assigns

    socket
    |> assign(:users, Enum.map(users, &(if &1.id == user_role.user_id, do: %{%{&1 | user_role: user_role} | role: Roles.get(user_role.role)}, else: &1)))
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
  def handle_event("timeframe", %{"timeframe" => timeframe}, socket) do
    %{date: o_date} = socket.assigns

    date = case Map.get(timeframe, "date", "") do
      ""   -> o_date
      date -> date |> Date.from_iso8601!()
    end

    socket
    |> assign(:timeframe, Map.get(timeframe, "timeframe", "week"))
    |> assign(:date, date)
    |> assign(:page, 0)
    |> reload_items()
    |> res()
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: socket |> set_modal(:edit, id |> String.to_integer) |> res()

  @impl true
  def handle_event("save", %{"user_role" => params}, socket) do
    %{changeset: changeset} = socket.assigns

    UserRoles.create_or_update(changeset.data, params)
    |> case do
      {:ok, _user_role} ->
        socket |> assign(changeset: nil) |> res()
      {:error, changeset} ->
        socket |> assign(changeset: changeset) |> res()
    end
  end

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_users()
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
