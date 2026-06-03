defmodule HfgPortalWeb.Budget.Users.UsersLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Budget.Users.Modals.ChangeUserRoles

  alias Budget.{
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
    } = socket.assigns

    socket |> assign(:users, users ++ UserRoles.list(%{
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      preload:      [:user_role],
    }))
  end

  defp reload_items(socket), do: socket |> assign(:users, []) |> assign(:page, 0) |> fetch_users()

  defp fetch_roles(socket) do
    socket |> assign(:roles, Roles.list() |> Enum.map(&[value: &1.name, key: &1.name]))
  end

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :edit, id) do
    %{modal_stack: modal_stack, current_user: user} = socket.assigns

    changeset =
      id
      |> UserRoles.get(:user)
      |> case do
        nil        -> UserRoles.new_changeset()
        user_role  -> UserRoles.change(user_role)
      end

    socket |> assign(:modal_stack, [%Modal{
      modal:     :edit,
      id:        id,
      module:    ChangeUserRoles,
      changeset: changeset,
      user:      user,
      opts:      %{user_id: id}
    } | modal_stack])
  end

  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: UserRoles.subscribe()

    socket
    |> bnw_verify_user_token(session, "Budget", "Users")
    |> assign(:session,      %{})
    |> assign(:page,         0)
    |> assign(:per_page,     50)
    |> assign(:users,        [])
    |> assign(:modal_stack,  [])
    |> assign(:search_map,   %{})
    |> assign(:search_stack, [])
    |> assign(:sort_stack,   [])
    |> handle_params(session)
    |> fetch_users()
    |> fetch_roles()
    |> res(:ok)
  end

  defp handle_params(socket, %{"search" => _} = session) do
    socket |> search_handle_params(session) |> handle_params(Map.delete(session, "search"))
  end
  defp handle_params(socket, %{"sort" => _} = session) do
    socket |> sort_handle_params(session) |> handle_params(Map.delete(session, "sort"))
  end
  defp handle_params(socket, %{"app" => app} = session) do
    socket |> assign(:session, Map.put(socket.assigns.session, "app", app)) |> handle_params(Map.delete(session, "app"))
  end
  defp handle_params(socket, %{"page" => page} = session) do
    socket |> assign(:session, Map.put(socket.assigns.session, "page", page)) |> handle_params(Map.delete(session, "page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do
    socket |> assign(:session, Map.put(socket.assigns.session, "admin", admin)) |> handle_params(Map.delete(session, "admin"))
  end
  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:budget, :user_role, _], user_role}, socket) do
    %{users: users} = socket.assigns
    socket
    |> assign(:users, Enum.map(users, fn u ->
      if u.id == user_role.user_id,
        do:   %{u | user_role: user_role, role: Roles.get(user_role.role)},
        else: u
    end))
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
  def handle_event("edit", %{"id" => id}, socket),  do: socket |> set_modal(:edit, String.to_integer(id)) |> res()
  @impl true
  def handle_event("cancel", _, socket),             do: socket |> set_modal() |> res()
  @impl true
  def handle_event("load_more", _, socket) do
    socket |> assign(:page, socket.assigns.page + 1) |> fetch_users() |> res()
  end
  @impl true
  def handle_event("sort", params, socket),                       do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket),  do: socket |> search(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"field" => _} = params, socket),   do: socket |> search(params) |> res()
  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket),  do: socket |> search_reset_filter(field) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", _, socket),                   do: socket |> search_reset_filter() |> reload_items() |> res()
  @impl true
  def handle_event("hide_filter", _, socket),                     do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
