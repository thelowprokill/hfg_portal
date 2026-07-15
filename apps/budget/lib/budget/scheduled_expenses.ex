defmodule Budget.ScheduledExpenses do
  import Ecto.Query

  @topic   "budget:scheduled_expenses"
  @schema  Budget.ScheduledExpenses.ScheduledExpense
  @updated [:scheduled_expense, :updated]
  @created [:scheduled_expense, :created]
  @deleted [:scheduled_expense, :deleted]

  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def run_scheduled(date \\ Date.utc_today()) do
    expense_results =
      list_due(date)
      |> Enum.map(fn se ->
        result =
          Budget.Transactions.new()
          |> Budget.Transactions.create_or_update(%{
            bucket_id:            se.bucket_id,
            scheduled_expense_id: se.id,
            amount:               se.amount,
            description:          se.description,
            transaction_date:     date,
            type:                 "expense",
          })

        case result do
          {:ok, t} ->
            advance_due_date(se)
            %{status: :created, description: t.description, amount: t.amount}
          {:error, cs} ->
            %{status: :error, description: se.description, errors: inspect(cs.errors)}
        end
      end)

    sinking_results =
      (Budget.Buckets.list_all_sinking_funds() ++ Budget.Buckets.list_all_emergency_funds())
      |> Enum.reject(fn bucket ->
        Budget.Transactions.sinking_fund_deposit_this_month?(bucket.id, date.year, date.month)
      end)
      |> Enum.map(fn bucket ->
        result =
          Budget.Transactions.new()
          |> Budget.Transactions.create_or_update(%{
            bucket_id:        bucket.id,
            amount:           bucket.monthly_contribution,
            description:      "Monthly contribution",
            transaction_date: date,
            type:             "sinking_fund_deposit",
          })

        case result do
          {:ok, t}   -> %{status: :created, bucket: bucket.name, amount: t.amount}
          {:error, cs} -> %{status: :error, bucket: bucket.name, errors: inspect(cs.errors)}
        end
      end)

    %{scheduled_expenses: expense_results, sinking_contributions: sinking_results}
  end

  def list_for_bucket(bucket_id) do
    @schema
    |> where([s], s.bucket_id == ^bucket_id)
    |> order_by([s], s.description)
    |> Repo.all()
  end

  def list_due(date) do
    @schema
    |> where([s], s.active == true and s.next_due_date <= ^date)
    |> Repo.all()
  end

  def advance_due_date(%@schema{} = scheduled_expense) do
    next =
      case scheduled_expense.frequency do
        "weekly"  -> Date.add(scheduled_expense.next_due_date, 7)
        "monthly" -> shift_months(scheduled_expense.next_due_date, 1, scheduled_expense.day_of_month)
        "yearly"  -> shift_months(scheduled_expense.next_due_date, 12, scheduled_expense.day_of_month)
      end

    scheduled_expense
    |> change(%{next_due_date: next})
    |> Repo.update()
    |> notify_subscribers(@updated)
  end

  defp shift_months(date, months, day_of_month) do
    total_months = date.year * 12 + (date.month - 1) + months
    year         = div(total_months, 12)
    month        = rem(total_months, 12) + 1
    max_day      = Date.new!(year, month, 1) |> Date.days_in_month()

    Date.new!(year, month, min(day_of_month, max_day))
  end
end
