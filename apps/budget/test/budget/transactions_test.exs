defmodule Budget.TransactionsTest do
  use Budget.DataCase

  alias Budget.{Buckets, Transactions}
  alias Budget.Transactions.Transaction

  defp balance(bucket), do: Buckets.get(bucket.id).balance

  describe "changeset" do
    test "requires bucket, amount, description, date and type" do
      cs = Transaction.changeset(%Transaction{}, %{})
      errors = errors_on(cs)

      for f <- [:bucket_id, :amount, :description, :transaction_date, :type] do
        assert "can't be blank" in errors[f], "#{f} should be required"
      end
    end

    test "only accepts the three known types" do
      for type <- ~w(expense contribution sinking_fund_deposit) do
        assert Transaction.changeset(%Transaction{}, %{type: type}).errors[:type] == nil
      end

      assert %{type: ["is invalid"]} =
               errors_on(Transaction.changeset(%Transaction{}, %{type: "refund"}))
    end

    test "create_or_update with invalid attrs returns an error, broadcasts nothing and leaves the balance alone" do
      bucket = bucket_fixture()
      transaction_fixture(bucket_id: bucket.id, type: "contribution", amount: Decimal.new(50))
      Transactions.subscribe()

      assert {:error, cs} =
               Transactions.create_or_update(Transactions.new(), %{bucket_id: bucket.id, type: "nope"})

      refute cs.valid?
      refute_receive {[:transaction, _], _}
      assert dec_eq?(balance(bucket), 50)
    end
  end

  describe "bucket balance sync" do
    test "contributions and sinking deposits add, expenses subtract" do
      bucket = bucket_fixture()
      transaction_fixture(bucket_id: bucket.id, type: "contribution", amount: Decimal.new("100.00"))
      transaction_fixture(bucket_id: bucket.id, type: "sinking_fund_deposit", amount: Decimal.new("20.50"))
      transaction_fixture(bucket_id: bucket.id, type: "expense", amount: Decimal.new("30.25"))

      assert dec_eq?(balance(bucket), "90.25")
    end

    test "balance can go negative when expenses exceed deposits" do
      bucket = bucket_fixture()
      transaction_fixture(bucket_id: bucket.id, type: "contribution", amount: Decimal.new(10))
      transaction_fixture(bucket_id: bucket.id, type: "expense", amount: Decimal.new("10.01"))

      assert dec_eq?(balance(bucket), "-0.01")
    end

    test "a zero amount transaction is accepted and doesn't move the balance" do
      bucket = bucket_fixture()
      transaction_fixture(bucket_id: bucket.id, type: "expense", amount: Decimal.new(0))
      assert dec_eq?(balance(bucket), 0)
    end

    test "future-dated transactions count towards the stored balance" do
      bucket = bucket_fixture()
      transaction_fixture(bucket_id: bucket.id, type: "contribution", amount: Decimal.new(5), transaction_date: ~D[2099-01-01])
      assert dec_eq?(balance(bucket), 5)
    end

    test "only the transaction's own bucket is touched" do
      a = bucket_fixture()
      b = bucket_fixture()
      transaction_fixture(bucket_id: a.id, type: "contribution", amount: Decimal.new(40))
      transaction_fixture(bucket_id: b.id, type: "expense", amount: Decimal.new(15))

      assert dec_eq?(balance(a), 40)
      assert dec_eq?(balance(b), -15)
    end

    test "updating the amount or type resyncs" do
      bucket = bucket_fixture()
      t = transaction_fixture(bucket_id: bucket.id, type: "expense", amount: Decimal.new(10))
      assert dec_eq?(balance(bucket), -10)

      {:ok, t} = Transactions.create_or_update(t, %{amount: Decimal.new(25)})
      assert dec_eq?(balance(bucket), -25)

      {:ok, _} = Transactions.create_or_update(t, %{type: "contribution"})
      assert dec_eq?(balance(bucket), 25)
    end

    test "deleting resyncs, by struct and by id" do
      bucket = bucket_fixture()
      t1 = transaction_fixture(bucket_id: bucket.id, type: "contribution", amount: Decimal.new(100))
      t2 = transaction_fixture(bucket_id: bucket.id, type: "expense", amount: Decimal.new(30))

      {:ok, _} = Transactions.delete(t2)
      assert dec_eq?(balance(bucket), 100)

      {:ok, _} = Transactions.delete(t1.id)
      assert dec_eq?(balance(bucket), 0)
      assert Transactions.get(t1.id) == nil
    end

    test "moving a transaction to another bucket resyncs both buckets" do
      a = bucket_fixture()
      b = bucket_fixture()
      t = transaction_fixture(bucket_id: a.id, type: "contribution", amount: Decimal.new(40))

      {:ok, _} = Transactions.create_or_update(t, %{bucket_id: b.id})

      assert dec_eq?(balance(b), 40)
      assert dec_eq?(balance(a), 0)
    end

    test "amounts are stored rounded to cents" do
      bucket = bucket_fixture()
      t = transaction_fixture(bucket_id: bucket.id, type: "contribution", amount: Decimal.new("10.005"))
      transaction_fixture(bucket_id: bucket.id, type: "contribution", amount: Decimal.new("0.004"))

      assert dec_eq?(Transactions.get(t.id).amount, "10.01")
      assert dec_eq?(balance(bucket), "10.01")
    end
  end

  describe "pubsub" do
    test "broadcasts created/updated/deleted on the topic and the per-id topic" do
      bucket = bucket_fixture()
      Transactions.subscribe()

      t = transaction_fixture(bucket_id: bucket.id)
      assert_receive {[:transaction, :created], %Transaction{id: id}}
      assert id == t.id

      Transactions.subscribe(t.id)
      {:ok, _} = Transactions.create_or_update(t, %{description: "changed"})
      assert_receive {[:transaction, :updated], %Transaction{description: "changed"}}
      assert_receive {[:transaction, :updated], %Transaction{description: "changed"}}

      Transactions.unsubscribe(t.id)
      {:ok, _} = Transactions.delete(t)
      assert_receive {[:transaction, :deleted], %Transaction{id: ^id}}
      refute_receive {[:transaction, :deleted], _}
    end
  end

  describe "new_changeset/1" do
    test "defaults the date to today but keeps a given date" do
      assert Ecto.Changeset.get_field(Transactions.new_changeset(%{}), :transaction_date) == Date.utc_today()

      cs = Transactions.new_changeset(%{transaction_date: ~D[2020-01-02]})
      assert Ecto.Changeset.get_field(cs, :transaction_date) == ~D[2020-01-02]
    end

    test "validates like the schema changeset" do
      refute Transactions.new_changeset(%{}).valid?
    end
  end

  describe "listing" do
    setup do
      bucket = bucket_fixture()
      other = bucket_fixture()

      ts =
        for {date, type, amount} <- [
              {~D[2024-01-31], "expense", "1.00"},
              {~D[2024-02-01], "expense", "2.00"},
              {~D[2024-02-15], "contribution", "50.00"},
              {~D[2024-02-29], "expense", "4.00"},
              {~D[2024-02-29], "sinking_fund_deposit", "8.00"},
              {~D[2024-03-01], "expense", "16.00"}
            ] do
          transaction_fixture(bucket_id: bucket.id, transaction_date: date, type: type, amount: Decimal.new(amount))
        end

      transaction_fixture(bucket_id: other.id, transaction_date: ~D[2024-02-10], amount: Decimal.new("100.00"))
      %{bucket: bucket, other: other, ts: ts}
    end

    test "list_for_bucket is newest first and scoped to the bucket", %{bucket: bucket} do
      dates = Transactions.list_for_bucket(bucket.id) |> Enum.map(& &1.transaction_date)
      assert length(dates) == 6
      assert dates == Enum.sort(dates, {:desc, Date})
      assert Transactions.list_for_bucket(-1) == []
    end

    test "list_for_month includes the first and last day of a leap February only", %{bucket: bucket} do
      dates = Transactions.list_for_month(bucket.id, 2024, 2) |> Enum.map(& &1.transaction_date)
      assert Enum.sort(dates, {:desc, Date}) == dates
      assert Enum.uniq(dates) == [~D[2024-02-29], ~D[2024-02-15], ~D[2024-02-01]]
      assert length(dates) == 4
      assert Transactions.list_for_month(bucket.id, 2023, 2) == []
    end

    test "monthly_expense_total sums only expenses of that bucket and month", %{bucket: bucket, other: other} do
      assert dec_eq?(Transactions.monthly_expense_total(bucket.id, 2024, 2), "6.00")
      assert dec_eq?(Transactions.monthly_expense_total(bucket.id, 2024, 1), "1.00")
      assert dec_eq?(Transactions.monthly_expense_total(other.id, 2024, 2), "100.00")
      assert dec_eq?(Transactions.monthly_expense_total(bucket.id, 2024, 4), 0)
    end

    test "monthly_deposit_total sums contributions and sinking deposits", %{bucket: bucket} do
      assert dec_eq?(Transactions.monthly_deposit_total(bucket.id, 2024, 2), "58.00")
      assert dec_eq?(Transactions.monthly_deposit_total(bucket.id, 2024, 3), 0)
    end

    test "sinking_fund_deposit_this_month? only counts sinking deposits in the month", %{bucket: bucket} do
      assert Transactions.sinking_fund_deposit_this_month?(bucket.id, 2024, 2)
      refute Transactions.sinking_fund_deposit_this_month?(bucket.id, 2024, 1)
      refute Transactions.sinking_fund_deposit_this_month?(bucket.id, 2024, 3)
    end

    test "balance_as_of_date is inclusive of the date", %{bucket: bucket} do
      assert dec_eq?(Transactions.balance_as_of_date(bucket.id, ~D[2024-01-30]), 0)
      assert dec_eq?(Transactions.balance_as_of_date(bucket.id, ~D[2024-01-31]), "-1.00")
      assert dec_eq?(Transactions.balance_as_of_date(bucket.id, ~D[2024-02-15]), "47.00")
      # -1 -2 +50 -4 +8
      assert dec_eq?(Transactions.balance_as_of_date(bucket.id, ~D[2024-02-28]), "47.00")
      assert dec_eq?(Transactions.balance_as_of_date(bucket.id, ~D[2024-02-29]), "51.00")
      assert dec_eq?(Transactions.balance_as_of_date(-1, ~D[2024-02-29]), 0)
    end

    test "balance_as_of_month runs to the end of the month and matches the synced balance at the end", %{bucket: bucket} do
      assert dec_eq?(Transactions.balance_as_of_month(bucket.id, 2024, 2), "51.00")
      assert dec_eq?(Transactions.balance_as_of_month(bucket.id, 2024, 3), "35.00")
      assert dec_eq?(Buckets.get(bucket.id).balance, "35.00")
    end

    test "list_filtered by bucket, month and page", %{bucket: bucket} do
      assert length(Transactions.list_filtered()) == 7
      assert length(Transactions.list_filtered(%{bucket_id: bucket.id})) == 6

      feb = Transactions.list_filtered(%{year: 2024, month: 2})
      assert length(feb) == 5
      assert Enum.all?(feb, &(&1.transaction_date.month == 2))

      # a year without a month is not a filter
      assert length(Transactions.list_filtered(%{year: 1999})) == 7

      page0 = Transactions.list_filtered(%{bucket_id: bucket.id, page: 0, per_page: 4})
      page1 = Transactions.list_filtered(%{bucket_id: bucket.id, page: "1", per_page: "4"})
      assert length(page0) == 4
      assert length(page1) == 2
      assert hd(page0).transaction_date == ~D[2024-03-01]
      assert MapSet.disjoint?(MapSet.new(page0, & &1.id), MapSet.new(page1, & &1.id))
    end

    test "list_filtered sort_stack and search_stack", %{bucket: bucket} do
      transaction_fixture(bucket_id: bucket.id, description: "Groceries at Aldi")

      assert [%{description: "Groceries at Aldi"}] =
               Transactions.list_filtered(%{search_stack: [%{field: :description, val: "Aldi"}]})

      sorted = Transactions.list_filtered(%{bucket_id: bucket.id, sort_stack: [%{field: :amount, order: :desc}]})
      assert dec_eq?(hd(sorted).amount, "50.00")

      # unknown fields are ignored
      assert length(Transactions.list_filtered(%{search_stack: [%{field: :bogus, val: "x"}]})) == 8
    end

    test "list paginates and preloads", %{bucket: bucket} do
      assert length(Transactions.list(%{})) == 7
      assert length(Transactions.list(%{page: 0, per_page: 3})) == 3
      [t | _] = Transactions.list(%{preload: [:bucket]})
      assert %Budget.Buckets.Bucket{} = t.bucket
      assert Enum.any?(Transactions.list(%{preload: [:bucket]}), &(&1.bucket.id == bucket.id))
    end
  end

  test "created_by links to a hfg_portal user" do
    user = user_fixture(%{first_name: "Ann"})
    t = transaction_fixture(bucket_id: bucket_fixture().id, created_by_id: user.id)

    assert %Budget.Users.User{first_name: "Ann"} = Transactions.preload(t, %{preload: [:created_by]}).created_by
  end

  test "deleting a bucket cascades to its transactions" do
    bucket = bucket_fixture()
    t = transaction_fixture(bucket_id: bucket.id)
    {:ok, _} = Buckets.delete(bucket)
    assert Transactions.get(t.id) == nil
  end
end
