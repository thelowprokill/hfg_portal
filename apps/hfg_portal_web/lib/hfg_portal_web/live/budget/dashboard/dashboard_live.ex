defmodule HfgPortalWeb.Budget.Dashboard.DashboardLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Budget.Transactions.Modals.ChangeTransaction

  alias Budget.{
    Buckets,
    Transactions,
  }

  defp fetch_buckets(socket) do
    %{current_user: %{id: user_id}} = socket.assigns
    socket |> assign(:buckets, Buckets.list_for_user(user_id))
  end

  defp fetch_monthly_totals(socket) do
    %{buckets: buckets, selected_year: year, selected_month: month} = socket.assigns

    expense_totals =
      buckets
      |> Map.new(fn bucket ->
        {bucket.id, Transactions.monthly_expense_total(bucket.id, year, month)}
      end)

    deposit_totals =
      buckets
      |> Map.new(fn bucket ->
        {bucket.id, Transactions.monthly_deposit_total(bucket.id, year, month)}
      end)

    month_end_balances =
      buckets
      |> Map.new(fn bucket ->
        {bucket.id, Transactions.balance_as_of_month(bucket.id, year, month)}
      end)

    socket
    |> assign(:monthly_expenses,     expense_totals)
    |> assign(:monthly_deposits,     deposit_totals)
    |> assign(:month_end_balances,   month_end_balances)
  end

  defp fetch_bucket_transactions(socket) do
    case socket.assigns.selected_bucket do
      nil    -> socket
      bucket ->
        %{selected_year: year, selected_month: month} = socket.assigns
        socket
        |> assign(:transactions, Transactions.list_for_month(bucket.id, year, month))
        |> sync_selected_bucket()
    end
  end

  defp sync_selected_bucket(%{assigns: %{selected_bucket: nil}} = socket), do: socket
  defp sync_selected_bucket(socket) do
    %{buckets: buckets, selected_bucket: sel} = socket.assigns
    updated = Enum.find(buckets, sel, &(&1.id == sel.id))
    assign(socket, :selected_bucket, updated)
  end

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{modal_stack: modal_stack, current_user: user, buckets: buckets, selected_bucket: bucket} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeTransaction,
      changeset: Transactions.new_changeset(%{bucket_id: bucket.id}),
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

  defp shift_month(year, month, :prev) when month == 1,  do: {year - 1, 12}
  defp shift_month(year, month, :prev),                  do: {year, month - 1}
  defp shift_month(year, month, :next) when month == 12, do: {year + 1, 1}
  defp shift_month(year, month, :next),                  do: {year, month + 1}

  defp apply_month(socket, year, month) do
    %{session: session} = socket.assigns
    socket
    |> assign(:selected_year,  year)
    |> assign(:selected_month, month)
    |> assign(:session, session |> Map.put("year", to_string(year)) |> Map.put("month", to_string(month)))
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
  defp handle_params(socket, %{"bucket" => bucket_id} = session) do
    %{session: stored, buckets: buckets} = socket.assigns
    bucket = Enum.find(buckets, &(to_string(&1.id) == bucket_id))
    socket
    |> assign(:session, Map.put(stored, "bucket", bucket_id))
    |> assign(:selected_bucket, bucket)
    |> handle_params(Map.delete(session, "bucket"))
  end
  defp handle_params(socket, %{"year" => year, "month" => month} = session) do
    %{session: stored} = socket.assigns
    socket
    |> assign(:session, stored |> Map.put("year", year) |> Map.put("month", month))
    |> assign(:selected_year,  String.to_integer(year))
    |> assign(:selected_month, String.to_integer(month))
    |> handle_params(session |> Map.delete("year") |> Map.delete("month"))
  end
  defp handle_params(socket, _session), do: socket

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Buckets.subscribe()
      Transactions.subscribe()
    end

    today = Date.utc_today()

    socket
    |> bnw_verify_user_token(session, "Budget", "Dashboard")
    |> assign(:session,          %{})
    |> assign(:buckets,          [])
    |> assign(:monthly_expenses,   %{})
    |> assign(:monthly_deposits,   %{})
    |> assign(:month_end_balances, %{})
    |> assign(:selected_bucket,  nil)
    |> assign(:selected_year,    today.year)
    |> assign(:selected_month,   today.month)
    |> assign(:transactions,     [])
    |> assign(:modal_stack,      [])
    |> fetch_buckets()
    |> handle_params(session)
    |> fetch_monthly_totals()
    |> fetch_bucket_transactions()
    |> res(:ok)
  end

  @impl true
  def handle_info({[:bucket, _], _bucket}, socket) do
    socket |> fetch_buckets() |> fetch_monthly_totals() |> fetch_bucket_transactions() |> res()
  end

  @impl true
  def handle_info({[:transaction, _], _transaction}, socket) do
    socket |> fetch_buckets() |> fetch_monthly_totals() |> fetch_bucket_transactions() |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("reset_month", _, socket) do
    today = Date.utc_today()
    socket |> apply_month(today.year, today.month) |> fetch_monthly_totals() |> fetch_bucket_transactions() |> push_changes(:patch) |> res()
  end

  @impl true
  def handle_event("prev_month", _, socket) do
    {year, month} = shift_month(socket.assigns.selected_year, socket.assigns.selected_month, :prev)
    socket |> apply_month(year, month) |> fetch_monthly_totals() |> fetch_bucket_transactions() |> push_changes(:patch) |> res()
  end

  @impl true
  def handle_event("next_month", _, socket) do
    {year, month} = shift_month(socket.assigns.selected_year, socket.assigns.selected_month, :next)
    socket |> apply_month(year, month) |> fetch_monthly_totals() |> fetch_bucket_transactions() |> push_changes(:patch) |> res()
  end

  @impl true
  def handle_event("select_bucket", %{"id" => id}, socket) do
    %{session: session, buckets: buckets} = socket.assigns
    bucket = Enum.find(buckets, &(to_string(&1.id) == id))
    socket
    |> assign(:selected_bucket, bucket)
    |> assign(:session, Map.put(session, "bucket", id))
    |> fetch_bucket_transactions()
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("back", _, socket) do
    %{session: session} = socket.assigns
    socket
    |> assign(:selected_bucket, nil)
    |> assign(:transactions, [])
    |> assign(:session, Map.delete(session, "bucket"))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("add_new", _, socket), do: socket |> set_modal(:new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    socket |> set_modal(:edit, String.to_integer(id)) |> res()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    Transactions.delete(String.to_integer(id))
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
