defmodule HfgPortalWeb.Apis.Budget.BudgetController do
  use HfgPortalWeb, :controller

  alias Budget.{Accounts, AccountBalances, Buckets, Transactions, ScheduledExpenses}
  alias HfgPortalWeb.Apis.Budget.AuthController

  @routes [
    %{name: "dashboard",       method: "GET", function: &__MODULE__.dashboard/2,       role: :view,  description: "Monthly summary for all buckets" },
    %{name: "account_totals",  method: "GET", function: &__MODULE__.account_totals/2,  role: :view,  description: "Debit/credit account totals, sinking fund total, and net total money for a given month" },
    %{name: "account_history", method: "GET", function: &__MODULE__.account_history/2, role: :view,  description: "Account/bucket totals over a date range, one point per day or per month" },
    %{name: "run_scheduled",   method: "PUT", function: &__MODULE__.run_scheduled/2,   role: :admin, description: "Process due scheduled expenses and sinking fund contributions" }
  ]

  def call(%{method: method, query_params: %{"route" => route}} = conn, params) do
    Enum.find(@routes, &(&1.name == route && &1.method == method))
    |> case do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Route not found"})

      %{function: f} = route_config ->
        if AuthController.authorized?(conn, route_config),
          do: f.(conn, params),
          else: conn |> put_status(401) |> json(%{error: "Unauthorized"})
    end
  end

  def dashboard(%{params: params} = conn, _params) do
    today = Date.utc_today()
    year = parse_int(Map.get(params, "year")) || today.year
    month = parse_int(Map.get(params, "month")) || today.month

    buckets = Buckets.list()

    data =
      Enum.map(buckets, fn bucket ->
        %{
          id: bucket.id,
          name: bucket.name,
          type: bucket.type,
          description: bucket.description,
          balance: to_string(bucket.balance),
          monthly_budget: decimal_or_nil(bucket.monthly_budget),
          monthly_contribution: decimal_or_nil(bucket.monthly_contribution),
          max_balance: decimal_or_nil(bucket.max_balance),
          monthly_expenses: to_string(Transactions.monthly_expense_total(bucket.id, year, month)),
          monthly_deposits: to_string(Transactions.monthly_deposit_total(bucket.id, year, month)),
          month_end_balance: to_string(Transactions.balance_as_of_month(bucket.id, year, month))
        }
      end)

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      data: %{year: year, month: month, buckets: data}
    })
  end

  def account_totals(%{params: params} = conn, _params) do
    today = Date.utc_today()
    year = parse_int(Map.get(params, "year")) || today.year
    month = parse_int(Map.get(params, "month")) || today.month

    accounts = Accounts.list()
    account_balances = AccountBalances.map_for_month(year, month)

    sum_for_type = fn type ->
      accounts
      |> Enum.filter(&(&1.type == type))
      |> Enum.reduce(Decimal.new(0), fn account, acc ->
        Decimal.add(acc, Map.get(account_balances, account.id, Decimal.new(0)))
      end)
    end

    debit_total = sum_for_type.("debit")
    credit_total = sum_for_type.("credit")

    sum_bucket_balances = fn buckets ->
      buckets
      |> Enum.reduce(Decimal.new(0), fn bucket, acc ->
        Decimal.add(acc, Transactions.balance_as_of_month(bucket.id, year, month))
      end)
    end

    # An overspent sinking fund (negative balance) shouldn't inflate
    # total_money - floor each bucket at 0 before summing.
    sum_non_negative_bucket_balances = fn buckets ->
      buckets
      |> Enum.reduce(Decimal.new(0), fn bucket, acc ->
        balance =
          Transactions.balance_as_of_month(bucket.id, year, month) |> Decimal.max(Decimal.new(0))

        Decimal.add(acc, balance)
      end)
    end

    sinking_total = sum_non_negative_bucket_balances.(Buckets.list_all_sinking_funds())
    emergency_total = sum_bucket_balances.(Buckets.list_all_emergency_funds())

    # Sinking-fund/emergency-fund expenses are already netted into their bucket
    # balance (and therefore into sinking_total/emergency_total), so only sum
    # expenses for regular monthly-budget buckets here to avoid double-counting
    # in total_money.
    current_month_expenses =
      Buckets.list()
      |> Enum.filter(& &1.monthly_budget)
      |> Enum.reduce(Decimal.new(0), fn bucket, acc ->
        Decimal.add(acc, Transactions.monthly_expense_total(bucket.id, year, month))
      end)

    # Debit/credit balances are pulled live from the financial institutions,
    # so they already reflect this month's spending - subtracting
    # current_month_expenses again here would double-count it.
    total_money =
      debit_total
      |> Decimal.sub(credit_total)
      |> Decimal.sub(sinking_total)
      |> Decimal.sub(emergency_total)

    account_balances_as_of = AccountBalances.latest_date_for_month(year, month)

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      data: %{
        year: year,
        month: month,
        debit_total: to_string(debit_total),
        credit_total: to_string(credit_total),
        sinking_total: to_string(sinking_total),
        emergency_total: to_string(emergency_total),
        current_month_expenses: to_string(current_month_expenses),
        total_money: to_string(total_money),
        account_balances_as_of: account_balances_as_of
      }
    })
  end

  # `from`/`to` are ISO8601 dates (YYYY-MM-DD), defaulting to 6 months ago and
  # today. `interval` is "day" (default) or "month" - for "month" each point
  # is the month-end balance, clipped to `to` for the final point.
  def account_history(%{params: params} = conn, _params) do
    today = Date.utc_today()

    with {:ok, from_date} <- parse_date(Map.get(params, "from"), months_ago(today, 6)),
         {:ok, to_date} <- parse_date(Map.get(params, "to"), today),
         {:ok, interval} <- parse_interval(Map.get(params, "interval", "day")),
         false <- Date.compare(from_date, to_date) == :gt do
      accounts = Accounts.list()
      sinking_buckets = Buckets.list_all_sinking_funds()
      emergency_buckets = Buckets.list_all_emergency_funds()

      data =
        history_dates(from_date, to_date, interval)
        |> Enum.map(fn date ->
          totals = totals_for_date(date, accounts, sinking_buckets, emergency_buckets)

          %{
            date: date,
            debit_total: to_string(totals.debit),
            credit_total: to_string(totals.credit),
            sinking_total: to_string(totals.sinking),
            emergency_total: to_string(totals.emergency),
            total_money: to_string(totals.total)
          }
        end)

      conn
      |> put_status(:ok)
      |> json(%{
        response: :ok,
        date: DateTime.utc_now(),
        data: %{from: from_date, to: to_date, interval: interval, points: data}
      })
    else
      _ ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "from and to must be ISO8601 dates with from <= to, interval must be \"day\" or \"month\""})
    end
  end

  def run_scheduled(conn, _params) do
    %{scheduled_expenses: expenses, sinking_contributions: sinking} =
      ScheduledExpenses.run_scheduled()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      scheduled_expenses: expenses,
      sinking_contributions: sinking
    })
  end

  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)
  defp parse_int(i) when is_integer(i), do: i

  defp decimal_or_nil(nil), do: nil
  defp decimal_or_nil(d), do: to_string(d)

  defp parse_date(nil, default), do: {:ok, default}
  defp parse_date(s, _default), do: Date.from_iso8601(s)

  defp months_ago(date, n) do
    total = date.year * 12 + (date.month - 1) - n
    year = div(total, 12)
    month = rem(total, 12) + 1
    day = min(date.day, Date.days_in_month(Date.new!(year, month, 1)))
    Date.new!(year, month, day)
  end

  defp parse_interval(interval) when interval in ["day", "month"], do: {:ok, interval}
  defp parse_interval(_), do: :error

  defp history_dates(from_date, to_date, "day"), do: Date.range(from_date, to_date) |> Enum.to_list()

  defp history_dates(from_date, to_date, "month") do
    from_month = Date.beginning_of_month(from_date)
    to_month = Date.beginning_of_month(to_date)

    Stream.iterate(from_month, &add_months(&1, 1))
    |> Enum.take_while(&(Date.compare(&1, to_month) != :gt))
    |> Enum.map(&Date.end_of_month/1)
    |> Enum.map(&if(Date.compare(&1, to_date) == :gt, do: to_date, else: &1))
  end

  defp add_months(date, n) do
    total = date.year * 12 + (date.month - 1) + n
    Date.new!(div(total, 12), rem(total, 12) + 1, 1)
  end

  # Mirrors HfgPortalWeb.Budget.Dashboard.DashboardLive.totals_for_date/4 -
  # debit/credit are pulled live from the financial institutions as of `date`,
  # sinking funds are floored at 0 so an overspent one doesn't inflate totals.
  defp totals_for_date(date, accounts, sinking_buckets, emergency_buckets) do
    account_totals = AccountBalances.map_for_date(date)

    sum_for_type = fn type ->
      accounts
      |> Enum.filter(&(&1.type == type))
      |> Enum.reduce(Decimal.new(0), fn account, acc ->
        Decimal.add(acc, Map.get(account_totals, account.id, Decimal.new(0)))
      end)
    end

    sum_bucket_balances = fn buckets ->
      buckets
      |> Enum.reduce(Decimal.new(0), fn bucket, acc ->
        Decimal.add(acc, Transactions.balance_as_of_date(bucket.id, date))
      end)
    end

    sum_non_negative_bucket_balances = fn buckets ->
      buckets
      |> Enum.reduce(Decimal.new(0), fn bucket, acc ->
        balance = Transactions.balance_as_of_date(bucket.id, date) |> Decimal.max(Decimal.new(0))
        Decimal.add(acc, balance)
      end)
    end

    debit_total = sum_for_type.("debit")
    credit_total = sum_for_type.("credit")
    sinking_total = sum_non_negative_bucket_balances.(sinking_buckets)
    emergency_total = sum_bucket_balances.(emergency_buckets)

    total_money =
      debit_total
      |> Decimal.sub(credit_total)
      |> Decimal.sub(sinking_total)
      |> Decimal.sub(emergency_total)

    %{debit: debit_total, credit: credit_total, sinking: sinking_total, emergency: emergency_total, total: total_money}
  end
end
