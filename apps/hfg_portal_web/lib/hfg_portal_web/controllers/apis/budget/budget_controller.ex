defmodule HfgPortalWeb.Apis.Budget.BudgetController do
  use HfgPortalWeb, :controller

  alias Budget.{Buckets, Transactions, ScheduledExpenses}

  @routes [
    %{name: "dashboard",    method: "GET", function: &__MODULE__.dashboard/2,      description: "Monthly summary for all user buckets"},
    %{name: "run_scheduled", method: "PUT", function: &__MODULE__.run_scheduled/2,  description: "Process due scheduled expenses and sinking fund contributions"},
  ]

  def call(%{method: method, query_params: %{"route" => route}} = conn, params) do
    Enum.find(@routes, &(&1.name == route && &1.method == method))
    |> case do
      nil            -> conn |> put_status(:not_found) |> json(%{error: "Route not found"})
      %{function: f} -> f.(conn, params)
    end
  end

  def dashboard(%{params: params} = conn, _params) do
    %{id: user_id} = conn.assigns.current_api_user
    today = Date.utc_today()
    year  = parse_int(Map.get(params, "year"))  || today.year
    month = parse_int(Map.get(params, "month")) || today.month

    buckets = Buckets.list_for_user(user_id)

    data =
      Enum.map(buckets, fn bucket ->
        %{
          id:                   bucket.id,
          name:                 bucket.name,
          description:          bucket.description,
          balance:              to_string(bucket.balance),
          monthly_budget:       decimal_or_nil(bucket.monthly_budget),
          monthly_contribution: decimal_or_nil(bucket.monthly_contribution),
          max_balance:          decimal_or_nil(bucket.max_balance),
          monthly_expenses:     to_string(Transactions.monthly_expense_total(bucket.id, year, month)),
          monthly_deposits:     to_string(Transactions.monthly_deposit_total(bucket.id, year, month)),
          month_end_balance:    to_string(Transactions.balance_as_of_month(bucket.id, year, month)),
        }
      end)

    conn
    |> put_status(:ok)
    |> json(%{response: :ok, date: DateTime.utc_now(), data: %{year: year, month: month, buckets: data}})
  end

  def run_scheduled(conn, _params) do
    %{scheduled_expenses: expenses, sinking_contributions: sinking} =
      ScheduledExpenses.run_scheduled()

    conn
    |> put_status(:ok)
    |> json(%{
      response:              :ok,
      date:                  DateTime.utc_now(),
      scheduled_expenses:    expenses,
      sinking_contributions: sinking,
    })
  end

  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)
  defp parse_int(i) when is_integer(i), do: i

  defp decimal_or_nil(nil), do: nil
  defp decimal_or_nil(d),   do: to_string(d)
end
