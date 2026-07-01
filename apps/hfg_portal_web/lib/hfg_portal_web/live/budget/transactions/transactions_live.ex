defmodule HfgPortalWeb.Budget.Transactions.TransactionsLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Budget.Transactions.Modals.ChangeTransaction

  alias Budget.{
    Buckets,
    Transactions,
    Repo,
  }

  @preload [:bucket]

  defp fetch_transactions(socket) do
    %{
      page:         page,
      per_page:     per_page,
      transactions: transactions,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      filter_bucket_id: filter_bucket_id,
    } = socket.assigns

    fetched = Transactions.list(%{
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      preload:      @preload,
      bucket_id:    filter_bucket_id,
    })

    socket |> assign(:transactions, transactions ++ fetched)
  end

  defp reload_items(socket), do: socket |> assign(:transactions, []) |> assign(:page, 0) |> fetch_transactions()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{modal_stack: modal_stack, current_user: user, buckets: buckets} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeTransaction,
      changeset: Transactions.new_changeset(),
      live:      false,
      user:      user,
      opts:      %{buckets: buckets}
    } | modal_stack])
  end

  defp set_modal(socket, :edit, id) when not is_nil(id) do
    %{modal_stack: modal_stack, current_user: user, buckets: buckets} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :edit,
      id:        :edit,
      module:    ChangeTransaction,
      changeset: Transactions.get(id) |> Transactions.change(),
      live:      false,
      user:      user,
      opts:      %{buckets: buckets}
    } | modal_stack])
  end

  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: Transactions.subscribe()

    socket
    |> bnw_verify_user_token(session, "Budget", "Transactions")
    |> assign(:session,          %{})
    |> assign(:page,             0)
    |> assign(:per_page,         50)
    |> assign(:transactions,     [])
    |> assign(:modal_stack,      [])
    |> assign(:search_map,       %{})
    |> assign(:search_stack,     [])
    |> assign(:sort_stack,       [])
    |> assign(:filter_bucket_id, nil)
    |> assign(:buckets, Buckets.list())
    |> handle_params(session)
    |> fetch_transactions()
    |> res(:ok)
  end

  defp handle_params(socket, %{"app" => app} = session) do
    %{session: stored} = socket.assigns
    socket |> assign(:session, Map.put(stored, "app", app)) |> handle_params(Map.delete(session, "app"))
  end
  defp handle_params(socket, %{"page" => page} = session) do
    %{session: stored} = socket.assigns
    socket |> assign(:session, Map.put(stored, "page", page)) |> handle_params(Map.delete(session, "page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do
    %{session: stored} = socket.assigns
    socket |> assign(:session, Map.put(stored, "admin", admin)) |> handle_params(Map.delete(session, "admin"))
  end
  defp handle_params(socket, %{"bucket_id" => bucket_id} = session) do
    %{session: stored} = socket.assigns
    socket
    |> assign(:session, Map.put(stored, "bucket_id", bucket_id))
    |> assign(:filter_bucket_id, if(bucket_id == "", do: nil, else: String.to_integer(bucket_id)))
    |> handle_params(Map.delete(session, "bucket_id"))
  end
  defp handle_params(socket, %{"search" => _} = session) do
    socket |> search_handle_params(session) |> handle_params(Map.delete(session, "search"))
  end
  defp handle_params(socket, %{"sort" => _} = session) do
    socket |> sort_handle_params(session) |> handle_params(Map.delete(session, "sort"))
  end
  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:transaction, :created], transaction}, socket) do
    socket |> assign(:transactions, [transaction |> Repo.preload(@preload) | socket.assigns.transactions]) |> res()
  end
  @impl true
  def handle_info({[:transaction, :updated], transaction}, socket) do
    socket |> assign(:transactions, Enum.map(socket.assigns.transactions, &(if &1.id == transaction.id, do: transaction |> Repo.preload(@preload), else: &1))) |> res()
  end
  @impl true
  def handle_info({[:transaction, :deleted], transaction}, socket) do
    socket |> assign(:transactions, Enum.reject(socket.assigns.transactions, &(&1.id == transaction.id))) |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("add_new", _, socket),                          do: socket |> set_modal(:new) |> res()
  @impl true
  def handle_event("edit", %{"id" => id}, socket),                 do: socket |> set_modal(:edit, String.to_integer(id)) |> res()
  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    Transactions.delete(String.to_integer(id))
    socket |> res()
  end
  @impl true
  def handle_event("filter_bucket", %{"bucket_id" => ""}, socket) do
    %{session: session} = socket.assigns
    socket
    |> assign(:filter_bucket_id, nil)
    |> assign(:session, Map.delete(session, "bucket_id"))
    |> reload_items()
    |> push_changes(:patch)
    |> res()
  end
  @impl true
  def handle_event("filter_bucket", %{"bucket_id" => id}, socket) do
    %{session: session} = socket.assigns
    socket
    |> assign(:filter_bucket_id, String.to_integer(id))
    |> assign(:session, Map.put(session, "bucket_id", id))
    |> reload_items()
    |> push_changes(:patch)
    |> res()
  end
  @impl true
  def handle_event("cancel", _, socket),                           do: socket |> set_modal() |> res()
  @impl true
  def handle_event("load_more", _, socket) do
    socket |> assign(:page, socket.assigns.page + 1) |> fetch_transactions() |> res()
  end
  @impl true
  def handle_event("sort", params, socket),                        do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket),   do: socket |> search(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"field" => _} = params, socket),    do: socket |> search(params) |> res()
  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket),  do: socket |> search_reset_filter(field) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", _, socket),                    do: socket |> search_reset_filter() |> reload_items() |> res()
  @impl true
  def handle_event("hide_filter", _, socket),                      do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
