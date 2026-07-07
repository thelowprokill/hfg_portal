defmodule HfgPortalWeb.Budget.Accounts.AccountsLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Budget.Accounts.Modals.ChangeAccount

  alias Budget.Accounts

  defp fetch_accounts(socket) do
    %{
      page: page,
      per_page: per_page,
      accounts: accounts,
      search_stack: search_stack,
      sort_stack: sort_stack
    } = socket.assigns

    fetched =
      Accounts.list(%{
        page: page,
        per_page: per_page,
        search_stack: search_stack,
        sort_stack: sort_stack
      })

    socket |> assign(:accounts, accounts ++ fetched)
  end

  defp reload_items(socket),
    do: socket |> assign(:accounts, []) |> assign(:page, 0) |> fetch_accounts()

  defp set_modal(socket, type \\ nil, id \\ nil)

  defp set_modal(socket, :new, _) do
    %{modal_stack: modal_stack, current_user: user} = socket.assigns

    socket
    |> assign(:modal_stack, [
      %Modal{
        modal: :new,
        id: :new,
        module: ChangeAccount,
        changeset: Accounts.new_changeset(%{user_id: user.id}),
        live: false,
        user: user,
        opts: %{}
      }
      | modal_stack
    ])
  end

  defp set_modal(socket, :edit, id) when not is_nil(id) do
    %{modal_stack: modal_stack, current_user: user} = socket.assigns

    socket
    |> assign(:modal_stack, [
      %Modal{
        modal: :edit,
        id: :edit,
        module: ChangeAccount,
        changeset: Accounts.get(id) |> Accounts.change(),
        live: false,
        user: user,
        opts: %{}
      }
      | modal_stack
    ])
  end

  defp set_modal(socket, _, _),
    do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: Accounts.subscribe()

    socket
    |> bnw_verify_user_token(session, "Budget", "Accounts")
    |> assign(:session, %{})
    |> assign(:page, 0)
    |> assign(:per_page, 50)
    |> assign(:accounts, [])
    |> assign(:modal_stack, [])
    |> assign(:search_map, %{})
    |> assign(:search_stack, [])
    |> assign(:sort_stack, [])
    |> handle_params(session)
    |> fetch_accounts()
    |> res(:ok)
  end

  defp handle_params(socket, %{"app" => app} = session) do
    %{session: stored} = socket.assigns

    socket
    |> assign(:session, Map.put(stored, "app", app))
    |> handle_params(Map.delete(session, "app"))
  end

  defp handle_params(socket, %{"page" => page} = session) do
    %{session: stored} = socket.assigns

    socket
    |> assign(:session, Map.put(stored, "page", page))
    |> handle_params(Map.delete(session, "page"))
  end

  defp handle_params(socket, %{"admin" => admin} = session) do
    %{session: stored} = socket.assigns

    socket
    |> assign(:session, Map.put(stored, "admin", admin))
    |> handle_params(Map.delete(session, "admin"))
  end

  defp handle_params(socket, %{"search" => _} = session) do
    socket |> search_handle_params(session) |> handle_params(Map.delete(session, "search"))
  end

  defp handle_params(socket, %{"sort" => _} = session) do
    socket |> sort_handle_params(session) |> handle_params(Map.delete(session, "sort"))
  end

  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:account, :created], account}, socket) do
    socket |> assign(:accounts, [account | socket.assigns.accounts]) |> res()
  end

  @impl true
  def handle_info({[:account, :updated], account}, socket) do
    socket
    |> assign(
      :accounts,
      Enum.map(socket.assigns.accounts, &if(&1.id == account.id, do: account, else: &1))
    )
    |> res()
  end

  @impl true
  def handle_info({[:account, :deleted], account}, socket) do
    socket
    |> assign(:accounts, Enum.reject(socket.assigns.accounts, &(&1.id == account.id)))
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
  def handle_event("edit", %{"id" => id}, socket),
    do: socket |> set_modal(:edit, String.to_integer(id)) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    Accounts.delete(String.to_integer(id))
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()
  @impl true
  def handle_event("load_more", _, socket) do
    socket |> assign(:page, socket.assigns.page + 1) |> fetch_accounts() |> res()
  end

  @impl true
  def handle_event("sort", params, socket), do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket),
    do: socket |> search(params) |> reload_items() |> res()

  @impl true
  def handle_event("search", %{"field" => _} = params, socket),
    do: socket |> search(params) |> res()

  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket),
    do: socket |> search_reset_filter(field) |> reload_items() |> res()

  @impl true
  def handle_event("reset_filters", _, socket),
    do: socket |> search_reset_filter() |> reload_items() |> res()

  @impl true
  def handle_event("hide_filter", _, socket), do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
