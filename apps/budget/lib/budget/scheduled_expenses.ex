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
    advanced = Date.shift(date, month: months)
    max_day  = Date.days_in_month(advanced)
    %{advanced | day: min(day_of_month, max_day)}
  end
end
