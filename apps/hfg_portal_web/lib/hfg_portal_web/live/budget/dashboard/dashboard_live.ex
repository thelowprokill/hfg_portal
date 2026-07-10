defmodule HfgPortalWeb.Budget.Dashboard.DashboardLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Budget.Transactions.Modals.ChangeTransaction

  alias Budget.{
    Accounts,
    AccountBalances,
    Authorize,
    Buckets,
    Transactions,
    UserRoles
  }

  defp fetch_buckets(socket) do
    socket |> assign(:buckets, Buckets.list())
  end

  defp fetch_account_totals(socket) do
    %{selected_year: year, selected_month: month} = socket.assigns

    accounts = Accounts.list()
    sinking_buckets = Buckets.list_all_sinking_funds()
    account_balances_as_of = AccountBalances.latest_date_for_month(year, month)

    %{debit: debit_total, credit: credit_total, sinking: sinking_total, total: total_money} =
      totals_for_month(accounts, sinking_buckets, year, month)

    socket
    |> assign(:debit_total, debit_total)
    |> assign(:credit_total, credit_total)
    |> assign(:sinking_total, sinking_total)
    |> assign(:total_money, total_money)
    |> assign(:account_balances_as_of, account_balances_as_of)
  end

  # Debit/credit balances are pulled live from the financial institutions,
  # so they already reflect this month's spending - subtracting
  # current_month_expenses again here would double-count it.
  defp totals_for_month(accounts, sinking_buckets, year, month) do
    Date.new!(year, month, 1) |> Date.end_of_month() |> totals_for_date(accounts, sinking_buckets)
  end

  defp totals_for_date(date, accounts, sinking_buckets) do
    account_totals = AccountBalances.map_for_date(date)

    sum_for_type = fn type ->
      accounts
      |> Enum.filter(&(&1.type == type))
      |> Enum.reduce(Decimal.new(0), fn account, acc ->
        Decimal.add(acc, Map.get(account_totals, account.id, Decimal.new(0)))
      end)
    end

    debit_total = sum_for_type.("debit")
    credit_total = sum_for_type.("credit")

    sinking_total =
      sinking_buckets
      |> Enum.reduce(Decimal.new(0), fn bucket, acc ->
        Decimal.add(acc, Transactions.balance_as_of_date(bucket.id, date))
      end)

    total_money =
      debit_total
      |> Decimal.sub(credit_total)
      |> Decimal.sub(sinking_total)

    %{debit: debit_total, credit: credit_total, sinking: sinking_total, total: total_money}
  end

  defp account_history_points(from_date, to_date) do
    accounts = Accounts.list()
    sinking_buckets = Buckets.list_all_sinking_funds()

    Date.range(from_date, to_date)
    |> Enum.map(fn date ->
      date
      |> totals_for_date(accounts, sinking_buckets)
      |> Map.put(:label, Calendar.strftime(date, "%b %d"))
    end)
  end

  defp fetch_account_history(%{assigns: %{show_history: false}} = socket), do: socket

  defp fetch_account_history(socket) do
    %{history_from: from_date, history_to: to_date} = socket.assigns

    if Date.compare(from_date, to_date) != :gt do
      assign(socket, :account_history_points, account_history_points(from_date, to_date))
    else
      socket
    end
  end

  defp fetch_can_edit(socket) do
    %{current_user: user} = socket.assigns
    assign(socket, :can_edit, Authorize.can_edit?(user))
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

    # Sinking-fund expenses are already netted into their bucket balance (and
    # therefore into sinking_total), so only sum expenses for regular
    # monthly-budget buckets here to avoid double-counting in total_money.
    current_month_expenses =
      buckets
      |> Enum.filter(& &1.monthly_budget)
      |> Enum.reduce(Decimal.new(0), fn bucket, acc ->
        Decimal.add(acc, Map.get(expense_totals, bucket.id, Decimal.new(0)))
      end)

    socket
    |> assign(:monthly_expenses, expense_totals)
    |> assign(:monthly_deposits, deposit_totals)
    |> assign(:month_end_balances, month_end_balances)
    |> assign(:current_month_expenses, current_month_expenses)
  end

  defp fetch_bucket_transactions(socket) do
    case socket.assigns.selected_bucket do
      nil ->
        socket

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
    %{modal_stack: modal_stack, current_user: user, buckets: buckets, selected_bucket: bucket} =
      socket.assigns

    socket
    |> assign(:modal_stack, [
      %Modal{
        modal: :new,
        id: :new,
        module: ChangeTransaction,
        changeset: Transactions.new_changeset(%{bucket_id: bucket.id}),
        live: false,
        user: user,
        opts: %{buckets: buckets}
      }
      | modal_stack
    ])
  end

  defp set_modal(socket, :edit, id) when not is_nil(id) do
    %{modal_stack: modal_stack, current_user: user, buckets: buckets} = socket.assigns

    socket
    |> assign(:modal_stack, [
      %Modal{
        modal: :edit,
        id: :edit,
        module: ChangeTransaction,
        changeset: Transactions.get(id) |> Transactions.change(),
        live: false,
        user: user,
        opts: %{buckets: buckets}
      }
      | modal_stack
    ])
  end

  defp set_modal(socket, _, _),
    do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  defp shift_month(year, month, :prev) when month == 1, do: {year - 1, 12}
  defp shift_month(year, month, :prev), do: {year, month - 1}
  defp shift_month(year, month, :next) when month == 12, do: {year + 1, 1}
  defp shift_month(year, month, :next), do: {year, month + 1}

  defp apply_month(socket, year, month) do
    %{session: session} = socket.assigns

    socket
    |> assign(:selected_year, year)
    |> assign(:selected_month, month)
    |> assign(
      :session,
      session |> Map.put("year", to_string(year)) |> Map.put("month", to_string(month))
    )
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
    |> assign(:selected_year, String.to_integer(year))
    |> assign(:selected_month, String.to_integer(month))
    |> handle_params(session |> Map.delete("year") |> Map.delete("month"))
  end

  defp handle_params(socket, %{"history" => _} = session) do
    %{session: stored} = socket.assigns

    socket
    |> assign(:session, Map.put(stored, "history", "1"))
    |> assign(:show_history, true)
    |> handle_params(Map.delete(session, "history"))
  end

  defp handle_params(socket, %{"history_from" => from, "history_to" => to} = session) do
    %{session: stored} = socket.assigns

    with {:ok, from_date} <- Date.from_iso8601(from),
         {:ok, to_date} <- Date.from_iso8601(to) do
      socket
      |> assign(:session, stored |> Map.put("history_from", from) |> Map.put("history_to", to))
      |> assign(:history_from, from_date)
      |> assign(:history_to, to_date)
    else
      _ -> socket
    end
    |> handle_params(session |> Map.delete("history_from") |> Map.delete("history_to"))
  end

  defp handle_params(socket, _session), do: socket

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
      AccountBalances.subscribe()
      Buckets.subscribe()
      Transactions.subscribe()
      UserRoles.subscribe()
    end

    today = Date.utc_today()

    socket
    |> bnw_verify_user_token(session, "Budget", "Dashboard")
    |> assign(:session, %{})
    |> assign(:buckets, [])
    |> assign(:monthly_expenses, %{})
    |> assign(:monthly_deposits, %{})
    |> assign(:month_end_balances, %{})
    |> assign(:debit_total, Decimal.new(0))
    |> assign(:credit_total, Decimal.new(0))
    |> assign(:sinking_total, Decimal.new(0))
    |> assign(:current_month_expenses, Decimal.new(0))
    |> assign(:total_money, Decimal.new(0))
    |> assign(:account_balances_as_of, nil)
    |> assign(:selected_bucket, nil)
    |> assign(:selected_year, today.year)
    |> assign(:selected_month, today.month)
    |> assign(:transactions, [])
    |> assign(:show_history, false)
    |> assign(:history_from, Date.add(today, -90))
    |> assign(:history_to, today)
    |> assign(:account_history_points, [])
    |> assign(:modal_stack, [])
    |> assign(:can_edit, false)
    |> fetch_buckets()
    |> fetch_can_edit()
    |> handle_params(session)
    |> fetch_monthly_totals()
    |> fetch_account_totals()
    |> fetch_bucket_transactions()
    |> fetch_account_history()
    |> res(:ok)
  end

  @impl true
  def handle_info({[:budget, :user_role, _], user_role}, socket) do
    if user_role.user_id == socket.assigns.current_user.id,
      do: socket |> fetch_can_edit() |> res(),
      else: socket |> res()
  end

  @impl true
  def handle_info({[:bucket, _], _bucket}, socket) do
    socket
    |> fetch_buckets()
    |> fetch_monthly_totals()
    |> fetch_account_totals()
    |> fetch_bucket_transactions()
    |> fetch_account_history()
    |> res()
  end

  @impl true
  def handle_info({[:transaction, _], _transaction}, socket) do
    socket
    |> fetch_buckets()
    |> fetch_monthly_totals()
    |> fetch_account_totals()
    |> fetch_bucket_transactions()
    |> fetch_account_history()
    |> res()
  end

  @impl true
  def handle_info({[:account, _], _account}, socket) do
    socket |> fetch_account_totals() |> fetch_account_history() |> res()
  end

  @impl true
  def handle_info({[:account_balance, _], _account_balance}, socket) do
    socket |> fetch_account_totals() |> fetch_account_history() |> res()
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

    socket
    |> apply_month(today.year, today.month)
    |> fetch_monthly_totals()
    |> fetch_account_totals()
    |> fetch_bucket_transactions()
    |> fetch_account_history()
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("prev_month", _, socket) do
    {year, month} =
      shift_month(socket.assigns.selected_year, socket.assigns.selected_month, :prev)

    socket
    |> apply_month(year, month)
    |> fetch_monthly_totals()
    |> fetch_account_totals()
    |> fetch_bucket_transactions()
    |> fetch_account_history()
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("next_month", _, socket) do
    {year, month} =
      shift_month(socket.assigns.selected_year, socket.assigns.selected_month, :next)

    socket
    |> apply_month(year, month)
    |> fetch_monthly_totals()
    |> fetch_account_totals()
    |> fetch_bucket_transactions()
    |> fetch_account_history()
    |> push_changes(:patch)
    |> res()
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
    |> assign(:show_history, false)
    |> assign(:account_history_points, [])
    |> assign(
      :session,
      session |> Map.delete("bucket") |> Map.delete("history") |> Map.delete("history_from") |> Map.delete("history_to")
    )
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("add_new", _, %{assigns: %{can_edit: true}} = socket),
    do: socket |> set_modal(:new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, %{assigns: %{can_edit: true}} = socket) do
    socket |> set_modal(:edit, String.to_integer(id)) |> res()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: %{can_edit: true}} = socket) do
    Transactions.delete(String.to_integer(id))
    socket |> res()
  end

  @impl true
  def handle_event("show_account_history", _, socket) do
    %{session: session} = socket.assigns

    socket
    |> assign(:show_history, true)
    |> assign(:session, Map.put(session, "history", "1"))
    |> fetch_account_history()
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("update_history_range", %{"range" => %{"from" => from, "to" => to}}, socket) do
    %{session: session} = socket.assigns

    with {:ok, from_date} <- Date.from_iso8601(from),
         {:ok, to_date} <- Date.from_iso8601(to) do
      socket
      |> assign(:history_from, from_date)
      |> assign(:history_to, to_date)
      |> assign(:session, session |> Map.put("history_from", from) |> Map.put("history_to", to))
      |> fetch_account_history()
      |> push_changes(:patch)
      |> res()
    else
      _ -> socket |> res()
    end
  end

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
