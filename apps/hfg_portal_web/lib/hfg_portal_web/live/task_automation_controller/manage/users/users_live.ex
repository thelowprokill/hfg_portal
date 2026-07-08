defmodule HfgPortalWeb.TaskAutomationController.Manage.Users.UsersLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.TaskAutomationController.Manage.Users.Modals.{
    ChangeRoles,
  }

  #@preload [user_roles: :role]
  @preload []

  defp fetch_users(socket) do
    %{
      module:       module,
      page:         page, 
      per_page:     per_page, 
      users:        users,
      search_stack: search_stack,
      sort_stack:   sort_stack
    } = socket.assigns

    socket |> assign(:users, users ++ module.list(
      %{
        page:         page, 
        per_page:     per_page, 
        search_stack: search_stack,
        sort_stack:   sort_stack,
        active:       true,
        preload:      @preload,
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end
  defp reload_items(socket), do: socket |> assign(:users, []) |> fetch_users()

  defp fetch_roles(socket), do: socket |> assign(:roles, socket.assigns.roles_module.list() |> fn x -> [[key: "All", value: ""]] ++ Enum.map(x, &([value: &1.name, key: &1.name])) end.())

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :edit, id) do
    %{
      module:       module,
      roles_module: roles_module,
      current_user: user,
      modal_stack:  modal_stack
    } = socket.assigns

    changeset = 
      id
      |> module.get(:user)
      |> case do
        nil  -> module.new_changeset()
        user -> module.change(user)
      end

    socket |> assign(:modal_stack, [%Modal{
      id: id,
      modal:     :edit,
      module:    ChangeUserRoles,
      changeset: changeset,
      user:      user,
      opts:      %{module: module, roles_module: roles_module, user_id: id, user: HfgPortal.Accounts.get(id)}
    } | modal_stack])
  end
  defp set_modal(socket, :change_roles, id) do
    %{
      users:        users,
      current_user: user,
      modal_stack:  modal_stack
    } = socket.assigns

    socket
    |> assign(:modal_stack, [%Modal{
      modal:     :change_roles,
      id:        id,
      module:    ChangeRoles,
      live:      true,
      user:      user,
      opts:      %{user: Enum.find(users, &(&1.id == id))},
    } | modal_stack])
    
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    #module = Map.get(session, "module")
    #roles  = Map.get(session, "roles_module")
    #app    = Map.get(session, "app", "")
    #session = 
    #  session
    #  |> Map.delete("module")
    #  |> Map.delete("roles_module")
    #  |> Map.put("app", app)
    
    module = TaskAutomationController.UserRoles
    roles  = TaskAutomationController.Roles
    app    = "Task Automation Controller"

    if connected?(socket) do
      #module.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, app, "Users")
    |> assign(:module,       module)
    |> assign(:roles_module, roles)
    |> assign(:page,         0)
    |> assign(:per_page,     30)
    |> assign(:users,        [])
    |> assign(:changeset,    nil)
    |> assign(:search_map,   %{})
    |> assign(:search_stack, [])
    |> assign(:sort_stack,   [])
    |> assign(:modal_stack,  [])
    |> assign(:session,      %{})
    |> handle_params(session)
    |> fetch_users()
    |> fetch_roles()
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
  def handle_info({[_, :user_role, :created], user_role}, socket) do
    %{users: users, roles_module: roles_module} = socket.assigns

    socket
    |> assign(:users, Enum.map(users, &(if &1.id == user_role.user_id, do: %{%{&1 | user_role: user_role} | role: roles_module.get(user_role.role)}, else: &1)))
    |> res()
  end

  @impl true
  def handle_info({[_, :user_role, :updated], user_role}, socket) do
    %{users: users, roles_module: roles_module} = socket.assigns

    socket
    |> assign(:users, Enum.map(users, &(if &1.id == user_role.user_id, do: %{%{&1 | user_role: user_role} | role: roles_module.get(user_role.role)}, else: &1)))
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
  def handle_event("edit", %{"id" => id}, socket), do: socket |> set_modal(:edit, id |> String.to_integer) |> res()

  @impl true
  def handle_event("change_roles", %{"id" => id}, socket), do: socket |> set_modal(:change_roles, id |> String.to_integer) |> res()

  @impl true
  def handle_event("save", %{"user_role" => params}, socket) do
    %{
      module:    module,
      changeset: changeset
    } = socket.assigns

    module.create_or_update(changeset.data, params)
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
