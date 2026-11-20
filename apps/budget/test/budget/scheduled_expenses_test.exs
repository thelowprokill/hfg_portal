defmodule Budget.ScheduledExpensesTest do
  use Budget.DataCase

  alias Budget.{Buckets, ScheduledExpenses, Transactions}
  alias Budget.ScheduledExpenses.ScheduledExpense

  defp cs(attrs) do
    ScheduledExpense.changeset(
      %ScheduledExpense{},
      Enum.into(attrs, %{bucket_id: 1, amount: 10, description: "x", next_due_date: ~D[2026-01-01]})
    )
  end

  defp advance(attrs) do
    se = scheduled_expense_fixture(Map.put(attrs, :bucket_id, bucket_fixture().id))
    {:ok, se} = ScheduledExpenses.advance_due_date(se)
    se.next_due_date
  end

  describe "changeset" do
    test "requires the core fields" do
      errors = errors_on(ScheduledExpense.changeset(%ScheduledExpense{}, %{}))

      for f <- [:bucket_id, :amount, :description, :frequency, :next_due_date] do
        assert "can't be blank" in errors[f], "#{f} should be required"
      end
    end

    test "amount must be strictly positive" do
      base = %{frequency: "weekly", day_of_week: 0}
      assert cs(Map.put(base, :amount, "0.01")).valid?
      assert %{amount: ["must be greater than 0"]} = errors_on(cs(Map.put(base, :amount, 0)))
      assert %{amount: ["must be greater than 0"]} = errors_on(cs(Map.put(base, :amount, "-5")))
    end

    test "frequency must be monthly, weekly or yearly" do
      assert %{frequency: ["is invalid"]} = errors_on(cs(%{frequency: "daily"}))
    end

    test "weekly needs day_of_week in 0..6" do
      assert %{day_of_week: ["can't be blank"]} = errors_on(cs(%{frequency: "weekly"}))
      assert cs(%{frequency: "weekly", day_of_week: 0}).valid?
      assert cs(%{frequency: "weekly", day_of_week: 6}).valid?
      assert %{day_of_week: ["is invalid"]} = errors_on(cs(%{frequency: "weekly", day_of_week: 7}))
      assert %{day_of_week: ["is invalid"]} = errors_on(cs(%{frequency: "weekly", day_of_week: -1}))
    end

    test "monthly needs day_of_month in 1..28" do
      assert %{day_of_month: ["can't be blank"]} = errors_on(cs(%{frequency: "monthly"}))
      assert cs(%{frequency: "monthly", day_of_month: 1}).valid?
      assert cs(%{frequency: "monthly", day_of_month: 28}).valid?
      assert %{day_of_month: [_]} = errors_on(cs(%{frequency: "monthly", day_of_month: 0}))
      assert %{day_of_month: [_]} = errors_on(cs(%{frequency: "monthly", day_of_month: 29}))
    end

    test "yearly needs day_of_month 1..28 and month_of_year 1..12" do
      errors = errors_on(cs(%{frequency: "yearly"}))
      assert errors[:day_of_month] == ["can't be blank"]
      assert errors[:month_of_year] == ["can't be blank"]

      assert cs(%{frequency: "yearly", day_of_month: 28, month_of_year: 12}).valid?
      assert %{month_of_year: [_]} = errors_on(cs(%{frequency: "yearly", day_of_month: 1, month_of_year: 13}))
      assert %{month_of_year: [_]} = errors_on(cs(%{frequency: "yearly", day_of_month: 1, month_of_year: 0}))
      assert %{day_of_month: [_]} = errors_on(cs(%{frequency: "yearly", day_of_month: 31, month_of_year: 1}))
    end

    test "active defaults to true" do
      se = scheduled_expense_fixture(bucket_id: bucket_fixture().id)
      assert se.active
    end
  end

  describe "list_due/1 and list_for_bucket/1" do
    test "returns active expenses due on or before the date" do
      b = bucket_fixture()
      due_today = scheduled_expense_fixture(bucket_id: b.id, next_due_date: ~D[2026-03-15])
      overdue = scheduled_expense_fixture(bucket_id: b.id, next_due_date: ~D[2025-12-01])
      _future = scheduled_expense_fixture(bucket_id: b.id, next_due_date: ~D[2026-03-16])
      _inactive = scheduled_expense_fixture(bucket_id: b.id, next_due_date: ~D[2026-01-01], active: false)

      ids = ScheduledExpenses.list_due(~D[2026-03-15]) |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == Enum.sort([due_today.id, overdue.id])
      assert ScheduledExpenses.list_due(~D[2025-01-01]) == []
    end

    test "list_for_bucket is scoped and ordered by description" do
      b = bucket_fixture()
      for d <- ["Water", "Electric", "Gas"], do: scheduled_expense_fixture(bucket_id: b.id, description: d)
      scheduled_expense_fixture(bucket_id: bucket_fixture().id, description: "Other")

      assert Enum.map(ScheduledExpenses.list_for_bucket(b.id), & &1.description) == ["Electric", "Gas", "Water"]
    end
  end

  describe "advance_due_date/1" do
    test "weekly adds seven days" do
      assert advance(%{frequency: "weekly", day_of_week: 3, next_due_date: ~D[2026-12-29]}) == ~D[2027-01-05]
    end

    test "monthly moves to day_of_month of the next month, across a year end" do
      assert advance(%{frequency: "monthly", day_of_month: 15, next_due_date: ~D[2026-03-15]}) == ~D[2026-04-15]
      assert advance(%{frequency: "monthly", day_of_month: 15, next_due_date: ~D[2026-12-15]}) == ~D[2027-01-15]
    end

    test "monthly snaps to day_of_month even when the stored date drifted" do
      assert advance(%{frequency: "monthly", day_of_month: 28, next_due_date: ~D[2026-01-31]}) == ~D[2026-02-28]
      assert advance(%{frequency: "monthly", day_of_month: 5, next_due_date: ~D[2026-01-20]}) == ~D[2026-02-05]
    end

    test "yearly adds twelve months" do
      assert advance(%{frequency: "yearly", day_of_month: 28, month_of_year: 2, next_due_date: ~D[2024-02-28]}) ==
               ~D[2025-02-28]
    end

    test "persists and broadcasts the update" do
      se = scheduled_expense_fixture(bucket_id: bucket_fixture().id)
      ScheduledExpenses.subscribe()
      {:ok, _} = ScheduledExpenses.advance_due_date(se)

      assert_receive {[:scheduled_expense, :updated], %ScheduledExpense{next_due_date: ~D[2026-04-15]}}
      assert ScheduledExpenses.get(se.id).next_due_date == ~D[2026-04-15]
    end
  end

  @date ~D[2026-03-15]

  describe "run_scheduled/1" do
    test "with nothing set up returns empty results" do
      assert ScheduledExpenses.run_scheduled(@date) == %{scheduled_expenses: [], sinking_contributions: []}
    end

    test "turns due expenses into dated expense transactions and advances them" do
      b = bucket_fixture()
      se = scheduled_expense_fixture(bucket_id: b.id, amount: Decimal.new("25.00"), next_due_date: ~D[2026-03-01])
      future = scheduled_expense_fixture(bucket_id: b.id, next_due_date: ~D[2026-03-16])
      inactive = scheduled_expense_fixture(bucket_id: b.id, next_due_date: ~D[2026-03-01], active: false)

      assert %{scheduled_expenses: [%{status: :created, description: "Netflix", amount: amount}]} =
               ScheduledExpenses.run_scheduled(@date)

      assert dec_eq?(amount, "25.00")

      assert [t] = Transactions.list_for_bucket(b.id)
      assert t.type == "expense"
      assert t.transaction_date == @date
      assert t.scheduled_expense_id == se.id
      assert dec_eq?(Buckets.get(b.id).balance, "-25.00")

      assert ScheduledExpenses.get(se.id).next_due_date == ~D[2026-04-15]
      assert ScheduledExpenses.get(future.id).next_due_date == ~D[2026-03-16]
      assert ScheduledExpenses.get(inactive.id).next_due_date == ~D[2026-03-01]
    end

    test "running twice on the same day does not double charge" do
      b = bucket_fixture()
      scheduled_expense_fixture(bucket_id: b.id)

      ScheduledExpenses.run_scheduled(@date)
      assert %{scheduled_expenses: []} = ScheduledExpenses.run_scheduled(@date)
      assert length(Transactions.list_for_bucket(b.id)) == 1
    end

    test "an expense overdue by several periods catches up one period per run" do
      b = bucket_fixture()
      se = scheduled_expense_fixture(bucket_id: b.id, frequency: "weekly", day_of_week: 0, next_due_date: ~D[2026-03-01])

      ScheduledExpenses.run_scheduled(@date)
      assert ScheduledExpenses.get(se.id).next_due_date == ~D[2026-03-08]
      ScheduledExpenses.run_scheduled(@date)
      assert ScheduledExpenses.get(se.id).next_due_date == ~D[2026-03-15]
      ScheduledExpenses.run_scheduled(@date)
      assert ScheduledExpenses.get(se.id).next_due_date == ~D[2026-03-22]
      assert %{scheduled_expenses: []} = ScheduledExpenses.run_scheduled(@date)
      assert length(Transactions.list_for_bucket(b.id)) == 3
    end

    test "deposits the monthly contribution into sinking and emergency funds once a month" do
      sinking =
        bucket_fixture(name: "B Car", type: "sinking_fund", monthly_contribution: Decimal.new(100), max_balance: Decimal.new(1200))

      emergency = bucket_fixture(name: "A Rainy day", type: "emergency_fund", monthly_contribution: Decimal.new(50))
      normal = bucket_fixture(name: "Food", monthly_contribution: Decimal.new(999))

      %{sinking_contributions: results} = ScheduledExpenses.run_scheduled(@date)
      assert results |> Enum.map(& &1.bucket) |> Enum.sort() == ["A Rainy day", "B Car"]
      assert Enum.all?(results, &(&1.status == :created))

      assert [t] = Transactions.list_for_bucket(sinking.id)
      assert t.type == "sinking_fund_deposit"
      assert t.description == "Monthly contribution"
      assert dec_eq?(Buckets.get(sinking.id).balance, 100)
      assert dec_eq?(Buckets.get(emergency.id).balance, 50)
      assert Transactions.list_for_bucket(normal.id) == []

      # later in the same month: nothing new
      assert %{sinking_contributions: []} = ScheduledExpenses.run_scheduled(~D[2026-03-31])
      # next month: a new deposit
      assert %{sinking_contributions: [_, _]} = ScheduledExpenses.run_scheduled(~D[2026-04-01])
      assert dec_eq?(Buckets.get(sinking.id).balance, 200)
    end

    test "a manual sinking deposit earlier in the month counts as this month's contribution" do
      sinking = bucket_fixture(type: "sinking_fund", monthly_contribution: Decimal.new(100), max_balance: Decimal.new(1200))
      transaction_fixture(bucket_id: sinking.id, type: "sinking_fund_deposit", amount: Decimal.new(30), transaction_date: ~D[2026-03-01])

      assert %{sinking_contributions: []} = ScheduledExpenses.run_scheduled(@date)
    end

    test "a sinking fund without a contribution is reported as an error, not raised" do
      bucket_fixture(name: "Empty", type: "sinking_fund")

      assert %{sinking_contributions: [%{status: :error, bucket: "Empty", errors: errors}]} =
               ScheduledExpenses.run_scheduled(@date)

      assert errors =~ "amount"
    end
  end

  test "deleting a scheduled expense keeps its transactions but unlinks them" do
    b = bucket_fixture()
    se = scheduled_expense_fixture(bucket_id: b.id)
    ScheduledExpenses.run_scheduled(@date)

    {:ok, _} = ScheduledExpenses.delete(se)
    assert [%{scheduled_expense_id: nil}] = Transactions.list_for_bucket(b.id)
  end

  test "deactivate/activate toggle the active flag" do
    se = scheduled_expense_fixture(bucket_id: bucket_fixture().id)
    {:ok, se} = ScheduledExpenses.deactivate(se)
    refute ScheduledExpenses.get(se.id).active
    assert ScheduledExpenses.list_due(~D[2030-01-01]) == []
    {:ok, _} = ScheduledExpenses.activate(se.id)
    assert ScheduledExpenses.get(se.id).active
  end
end
