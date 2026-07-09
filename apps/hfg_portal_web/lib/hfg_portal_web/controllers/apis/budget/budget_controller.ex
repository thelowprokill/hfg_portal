defmodule HfgPortalWeb.Apis.Budget.BudgetController do
  use HfgPortalWeb, :controller

  alias Budget.{Accounts, AccountBalances, Buckets, Transactions, ScheduledExpenses}
  alias HfgPortalWeb.Apis.Budget.AuthController

  @routes [
    %{name: "dashboard",      method: "GET", function: &__MODULE__.dashboard/2,      role: :view,  description: "Monthly summary for all buckets" },
    %{name: "account_totals", method: "GET", function: &__MODULE__.account_totals/2, role: :view,  description: "Debit/credit account totals, sinking fund total, and net total money for a given month" },
    %{name: "run_scheduled",  method: "PUT", function: &__MODULE__.run_scheduled/2,  role: :admin, description: "Process due scheduled expenses and sinking fund contributions" }
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

    sinking_total =
      Buckets.list_all_sinking_funds()
      |> Enum.reduce(Decimal.new(0), fn bucket, acc ->
        Decimal.add(acc, Transactions.balance_as_of_month(bucket.id, year, month))
      end)

    # Sinking-fund expenses are already netted into their bucket balance (and
    # therefore into sinking_total), so only sum expenses for regular
    # monthly-budget buckets here to avoid double-counting in total_money.
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
        current_month_expenses: to_string(current_month_expenses),
        total_money: to_string(total_money),
        account_balances_as_of: account_balances_as_of
      }
    })
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
end
