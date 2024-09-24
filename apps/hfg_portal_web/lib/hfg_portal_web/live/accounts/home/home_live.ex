defmodule HfgPortalWeb.Accounts.Home.HomeLive do
  use HfgPortalWeb, :live_view

  alias HfgPortal.Accounts
  alias HfgPortalWeb.Accounts.Home.Modals.ChangeAccounts

  defp fetch_accounts(socket) do
    %{ 
      accounts:     accounts,
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack,
    } = socket.assigns

    socket
    |> assign(:accounts, accounts ++ Accounts.list(%{
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack,
    }))
  end
  defp reload_items(socket), do: socket |> assign(:accounts, []) |> fetch_accounts()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeAccounts,
      changeset: Accounts.new_changeset(),
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
      module: ChangeAccounts,
      changeset: id |> Accounts.get() |> Accounts.change(),
      user: user
    } | modal_stack])
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Accounts", "Home")
    |> assign(:page,          0)
    |> assign(:per_page,      30)
    |> assign(:accounts,      [])
    |> assign(:modal_stack,   [])
    |> assign(:search_map,    %{}) # search map is for the search form
    |> assign(:search_stack,  [])  # search stack is the data for all the search fields
    |> assign(:sort_stack,    [])  # sort stack is the data for all the sort fields
    |> assign(:session,       %{}) # session is kept so that the session can be updated
    |> handle_params(session)      # here session is the second argument to mount
    |> fetch_accounts()
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

  # these are required to keep on the app, page and admin
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
  def handle_info({[:user, :created], user}, socket) do
    socket |> assign(:accounts, [user | socket.assigns.accounts]) |> res()
  end
  @impl true
  def handle_info({[:user, :updated], user}, socket) do
    socket |> assign(:accounts, Enum.map(socket.assigns.accounts, &(if &1.id == user.id, do: user, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:user, :deleted], user}, socket) do
    socket |> assign(:accounts, Enum.reject(socket.assigns.accounts, &(&1.id == user.id))) |> res()
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
    id |> String.to_integer |> Accounts.delete()
    socket |> res()
  end

  @impl true
  def handle_event("deactivate", %{"id" => id, "key" => key}, socket) do
    id |> String.to_integer() |> Accounts.deactivate(String.to_atom(key))
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"id" => id, "key" => key}, socket) do
    id |> String.to_integer() |> Accounts.activate(String.to_atom(key))
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_accounts()
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

