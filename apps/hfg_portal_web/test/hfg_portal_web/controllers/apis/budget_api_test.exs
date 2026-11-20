defmodule HfgPortalWeb.Apis.BudgetApiTest do
  use HfgPortalWeb.ApiCase

  alias Budget.{Accounts, AccountBalances, Buckets, Transactions, ScheduledExpenses}

  # {scope, method, route, required role}
  @routes [
    {"budget", "GET", "dashboard", :view},
    {"budget", "GET", "account_totals", :view},
    {"budget", "GET", "account_history", :view},
    {"budget", "GET", "balances", :view},
    {"budget", "PUT", "balance", :edit},
    {"budget", "PUT", "run_scheduled", :admin},
    {"budget:buckets", "GET", "buckets", :view},
    {"budget:buckets", "GET", "bucket", :view},
    {"budget:buckets", "PUT", "bucket", :admin},
    {"budget:buckets", "DELETE", "bucket", :admin},
    {"budget:transactions", "GET", "transactions", :view},
    {"budget:transactions", "GET", "transaction", :view},
    {"budget:transactions", "PUT", "transaction", :edit},
    {"budget:transactions", "DELETE", "transaction", :admin},
    {"budget:scheduled_expenses", "GET", "scheduled_expenses", :view},
    {"budget:scheduled_expenses", "GET", "scheduled_expense", :view},
    {"budget:scheduled_expenses", "PUT", "scheduled_expense", :admin},
    {"budget:scheduled_expenses", "DELETE", "scheduled_expense", :admin},
    {"budget:scheduled_expenses", "PUT", "run_scheduled", :admin}
  ]

  # roles that lack the required permission
  @below %{view: [nil, "None"], edit: [nil, "None", "View"], admin: [nil, "None", "View", "Edit"]}

  defp user_with(nil), do: api_user()
  defp user_with(role), do: api_user(%{budget: role})

  defp call(conn, role, method, scope, route, query \\ %{}),
    do: api(conn, method, token(user_with(role)), Map.merge(%{"scope" => scope, "route" => route}, query))

  defp dec(s), do: Decimal.new(s)
  defp assert_dec(s, expected), do: assert(Decimal.equal?(dec(s), dec(expected)), "#{inspect(s)} != #{expected}")

  defp bucket(attrs) do
    {:ok, b} = Buckets.create_or_update(Buckets.new(), Map.merge(%{user_id: 1, name: "b#{System.unique_integer([:positive])}"}, attrs))
    b
  end

  defp txn(bucket, type, amount, date \\ Date.utc_today()) do
    {:ok, t} =
      Transactions.create_or_update(Transactions.new(), %{
        bucket_id: bucket.id, type: type, amount: amount, description: type, transaction_date: date
      })

    t
  end

  defp account(type, name \\ nil) do
    {:ok, a} = Accounts.create_or_update(Accounts.new(), %{user_id: 1, name: name || "#{type}#{System.unique_integer([:positive])}", type: type})
    a
  end

  defp scheduled(bucket, attrs \\ %{}) do
    {:ok, se} =
      ScheduledExpenses.create_or_update(
        ScheduledExpenses.new(),
        Map.merge(%{bucket_id: bucket.id, amount: "12.50", description: "rent", frequency: "monthly", day_of_month: 5, next_due_date: ~D[2026-01-05]}, attrs)
      )

    se
  end

  describe "authorization" do
    test "every route refuses roles below the one it requires", %{conn: conn} do
      for {scope, method, route, required} <- @routes, role <- @below[required] do
        assert %{"error" => "Unauthorized"} = conn |> call(role, method, scope, route, %{"id" => "1"}) |> json_response(401),
               "#{method} #{scope}/#{route} let #{inspect(role)} through"
      end
    end

    test "unknown route or wrong method for a route is 404", %{conn: conn} do
      assert %{"error" => "Route not found"} = conn |> call("Admin", "GET", "budget", "nope") |> json_response(404)
      assert %{"error" => "Route not found"} = conn |> call("Admin", "DELETE", "budget", "dashboard") |> json_response(404)
      assert %{"error" => "Route not found"} = conn |> call("Admin", "PUT", "budget:buckets", "buckets") |> json_response(404)
    end
  end

  describe "budget:buckets" do
    test "lists buckets sorted by name, balance only for funds", %{conn: conn} do
      bucket(%{name: "B normal", monthly_budget: "300"})
      fund = bucket(%{name: "A fund", type: "sinking_fund", monthly_contribution: "50", max_balance: "500"})
      txn(fund, "contribution", "20")

      assert [a, b] = conn |> call("View", "GET", "budget:buckets", "buckets") |> data()
      assert %{"name" => "A fund", "type" => "sinking_fund", "monthly_contribution" => mc, "max_balance" => mb, "balance" => bal} = a
      assert_dec(mc, "50")
      assert_dec(mb, "500")
      assert_dec(bal, "20")
      assert %{"name" => "B normal", "balance" => nil, "monthly_contribution" => nil, "monthly_budget" => mbud, "monthly_expenses" => exp} = b
      assert_dec(mbud, "300")
      assert_dec(exp, "0")

      assert Map.keys(a) |> Enum.sort() ==
               ~w(balance description id max_balance monthly_budget monthly_contribution monthly_expenses name type user_id)
    end

    test "search_stack, sort_stack and paging", %{conn: conn} do
      for n <- ~w(apple banana cherry), do: bucket(%{name: n})

      search = Jason.encode!([%{field: "name", val: "an"}])
      assert [%{"name" => "banana"}] = conn |> call("View", "GET", "budget:buckets", "buckets", %{"search_stack" => search}) |> data()

      page = %{"page" => "1", "per_page" => "2"}
      assert [%{"name" => "cherry"}] = conn |> call("View", "GET", "budget:buckets", "buckets", page) |> data()
    end

    test "malformed search_stack / sort_stack is a 400", %{conn: conn} do
      for {k, v} <- [{"search_stack", "{"}, {"search_stack", ~s({"a":1})}, {"sort_stack", "nope"}] do
        assert %{"error" => msg} = conn |> call("View", "GET", "budget:buckets", "buckets", %{k => v}) |> json_response(400)
        assert msg =~ k
      end
    end

    test "get a bucket by id, unknown id is null data", %{conn: conn} do
      b = bucket(%{name: "one"})
      assert %{"id" => id, "name" => "one"} = conn |> call("View", "GET", "budget:buckets", "bucket", %{"id" => "#{b.id}"}) |> data()
      assert id == b.id
      assert conn |> call("View", "GET", "budget:buckets", "bucket", %{"id" => "#{b.id + 1000}"}) |> data() == nil
    end

    test "PUT creates a bucket owned by the caller, and updates without changing the owner", %{conn: conn} do
      admin = api_user(%{budget: "Admin"})
      put = &api(conn, "PUT", token(admin), Map.merge(%{"scope" => "budget:buckets", "route" => "bucket"}, &1))

      assert %{"id" => id, "user_id" => owner, "name" => "Groceries", "type" => "normal"} =
               put.(%{"name" => "Groceries", "monthly_budget" => "400"}) |> data()

      assert owner == admin.id

      other = api_user(%{budget: "Admin"})
      body = api(conn, "PUT", token(other), %{"scope" => "budget:buckets", "route" => "bucket", "id" => "#{id}", "name" => "Food"}) |> data()
      assert %{"name" => "Food", "user_id" => ^owner} = body
      assert Buckets.get(id).name == "Food"
    end

    test "PUT with invalid data returns the changeset errors (status 200, response error)", %{conn: conn} do
      body =
        conn
        |> call("Admin", "PUT", "budget:buckets", "bucket", %{"name" => "x", "type" => "sinking_fund", "monthly_contribution" => "5"})
        |> json_response(200)

      assert %{"response" => "error", "errors" => %{"max_balance" => ["is required when monthly_contribution is set"]}} = body

      assert %{"response" => "error", "errors" => %{"type" => [_]}} =
               conn |> call("Admin", "PUT", "budget:buckets", "bucket", %{"name" => "x", "type" => "bogus"}) |> json_response(200)

      assert Buckets.list(%{}) == []
    end

    test "DELETE removes the bucket", %{conn: conn} do
      b = bucket(%{})
      assert conn |> call("Admin", "DELETE", "budget:buckets", "bucket", %{"id" => "#{b.id}"}) |> data() == nil
      assert Buckets.get(b.id) == nil
    end

    test "a non-numeric id is a 400", %{conn: conn} do
      assert conn |> call("View", "GET", "budget:buckets", "bucket", %{"id" => "abc"}) |> json_response(400)
    end

    test "an unknown search field is ignored", %{conn: conn} do
      search = Jason.encode!([%{field: "no_such_field_#{System.unique_integer([:positive])}", val: "x"}])
      assert conn |> call("View", "GET", "budget:buckets", "buckets", %{"search_stack" => search}) |> data() == []
    end
  end

  describe "budget:transactions" do
    test "PUT (Edit) creates a transaction credited to the caller and syncs the bucket balance", %{conn: conn} do
      editor = api_user(%{budget: "Edit"})
      fund = bucket(%{type: "sinking_fund"})

      query = %{
        "scope" => "budget:transactions", "route" => "transaction",
        "bucket_id" => "#{fund.id}", "amount" => "75.50", "description" => "deposit",
        "transaction_date" => "2026-03-04", "type" => "contribution"
      }

      assert %{"id" => id, "created_by_id" => by, "amount" => amount, "transaction_date" => "2026-03-04", "type" => "contribution", "scheduled_expense_id" => nil} =
               conn |> api("PUT", token(editor), query) |> data()

      assert by == editor.id
      assert_dec(amount, "75.50")
      assert Decimal.equal?(Buckets.get(fund.id).balance, dec("75.50"))

      # update by id
      assert %{"id" => ^id, "description" => "fixed"} =
               conn |> api("PUT", token(editor), %{"scope" => "budget:transactions", "route" => "transaction", "id" => "#{id}", "description" => "fixed"}) |> data()
    end

    test "PUT with missing fields returns errors", %{conn: conn} do
      assert %{"response" => "error", "errors" => errors} =
               conn |> call("Edit", "PUT", "budget:transactions", "transaction", %{"description" => "x"}) |> json_response(200)

      assert Map.keys(errors) |> Enum.sort() == ~w(amount bucket_id transaction_date type)
    end

    test "lists filtered by bucket and month, newest first, paged", %{conn: conn} do
      b1 = bucket(%{})
      b2 = bucket(%{})
      t1 = txn(b1, "expense", "1", ~D[2026-02-10])
      t2 = txn(b1, "expense", "2", ~D[2026-02-20])
      _ = txn(b1, "expense", "3", ~D[2026-03-01])
      _ = txn(b2, "expense", "4", ~D[2026-02-15])

      ids = fn q -> conn |> call("View", "GET", "budget:transactions", "transactions", q) |> data() |> Enum.map(& &1["id"]) end

      assert ids.(%{"bucket_id" => "#{b1.id}", "year" => "2026", "month" => "2"}) == [t2.id, t1.id]
      assert length(ids.(%{})) == 4
      assert ids.(%{"bucket_id" => "#{b1.id}", "page" => "1", "per_page" => "2"}) == [t1.id]
    end

    test "get and delete (Admin) a transaction, delete re-syncs the bucket", %{conn: conn} do
      b = bucket(%{type: "emergency_fund"})
      t = txn(b, "contribution", "10")

      assert %{"id" => id, "bucket_id" => bid} = conn |> call("View", "GET", "budget:transactions", "transaction", %{"id" => "#{t.id}"}) |> data()
      assert {id, bid} == {t.id, b.id}

      assert conn |> call("Admin", "DELETE", "budget:transactions", "transaction", %{"id" => "#{t.id}"}) |> data() == nil
      assert Transactions.get(t.id) == nil
      assert Decimal.equal?(Buckets.get(b.id).balance, 0)
    end
  end

  describe "budget:scheduled_expenses" do
    test "PUT (Admin) creates and updates, invalid data returns errors", %{conn: conn} do
      b = bucket(%{})

      q = %{"bucket_id" => "#{b.id}", "amount" => "9.99", "description" => "phone", "frequency" => "weekly", "day_of_week" => "2", "next_due_date" => "2026-05-01"}

      assert %{"id" => id, "frequency" => "weekly", "day_of_week" => 2, "next_due_date" => "2026-05-01", "active" => true} =
               conn |> call("Admin", "PUT", "budget:scheduled_expenses", "scheduled_expense", q) |> data()

      assert %{"active" => false} =
               conn |> call("Admin", "PUT", "budget:scheduled_expenses", "scheduled_expense", %{"id" => "#{id}", "active" => "false"}) |> data()

      bad = %{q | "frequency" => "monthly", "amount" => "-1"}

      assert %{"response" => "error", "errors" => %{"amount" => _, "day_of_month" => _}} =
               conn |> call("Admin", "PUT", "budget:scheduled_expenses", "scheduled_expense", bad) |> json_response(200)
    end

    test "list, get and delete", %{conn: conn} do
      se = scheduled(bucket(%{}))

      assert [%{"id" => id, "description" => "rent", "day_of_month" => 5}] =
               conn |> call("View", "GET", "budget:scheduled_expenses", "scheduled_expenses") |> data()

      assert id == se.id
      assert %{"id" => ^id} = conn |> call("View", "GET", "budget:scheduled_expenses", "scheduled_expense", %{"id" => "#{id}"}) |> data()
      assert conn |> call("Admin", "DELETE", "budget:scheduled_expenses", "scheduled_expense", %{"id" => "#{id}"}) |> data() == nil
      assert ScheduledExpenses.get(id) == nil
    end

    test "list filters by bucket_id", %{conn: conn} do
      b1 = bucket(%{})
      se = scheduled(b1)
      scheduled(bucket(%{}))

      assert [%{"id" => id}] = conn |> call("View", "GET", "budget:scheduled_expenses", "scheduled_expenses", %{"bucket_id" => "#{b1.id}"}) |> data()
      assert id == se.id
    end

    test "run_scheduled books due expenses and monthly fund contributions, once", %{conn: conn} do
      b = bucket(%{name: "Bills"})
      se = scheduled(b, %{next_due_date: Date.add(Date.utc_today(), -1)})
      _future = scheduled(b, %{description: "later", next_due_date: Date.add(Date.utc_today(), 30)})
      bucket(%{name: "Fund", type: "sinking_fund", monthly_contribution: "25", max_balance: "100"})

      for scope <- ["budget:scheduled_expenses", "budget"] do
        body = conn |> call("Admin", "PUT", scope, "run_scheduled") |> json_response(200)
        assert body["response"] == "ok"

        if scope == "budget:scheduled_expenses" do
          assert [%{"status" => "created", "description" => "rent", "amount" => amt}] = body["scheduled_expenses"]
          assert_dec(amt, "12.50")
          assert [%{"status" => "created", "bucket" => "Fund", "amount" => c}] = body["sinking_contributions"]
          assert_dec(c, "25")
        else
          # second run: the expense moved on a month and the fund already got this month's deposit
          assert body["scheduled_expenses"] == []
          assert body["sinking_contributions"] == []
        end
      end

      assert Date.compare(ScheduledExpenses.get(se.id).next_due_date, Date.utc_today()) == :gt
      assert length(Transactions.list_for_bucket(b.id)) == 1
    end
  end

  describe "budget (summary + balances)" do
    test "dashboard summarises each bucket for the month", %{conn: conn} do
      b = bucket(%{name: "Food", monthly_budget: "200"})
      txn(b, "expense", "30", ~D[2026-02-03])
      txn(b, "contribution", "100", ~D[2026-02-01])
      txn(b, "expense", "5", ~D[2026-03-03])

      assert %{"year" => 2026, "month" => 2, "buckets" => [row]} =
               conn |> call("View", "GET", "budget", "dashboard", %{"year" => "2026", "month" => "2"}) |> data()

      assert row["name"] == "Food"
      assert_dec(row["monthly_expenses"], "30")
      assert_dec(row["monthly_deposits"], "100")
      assert_dec(row["month_end_balance"], "70")
      # balance is the all-time running total
      assert_dec(row["balance"], "65")
    end

    test "dashboard defaults to the current month", %{conn: conn} do
      today = Date.utc_today()
      assert %{"year" => y, "month" => m, "buckets" => []} = conn |> call("View", "GET", "budget", "dashboard") |> data()
      assert {y, m} == {today.year, today.month}
    end

    test "account_totals: debit - credit - funds, overspent sinking funds floored at 0", %{conn: conn} do
      debit = account("debit")
      credit = account("credit")
      {:ok, _} = AccountBalances.upsert(debit.id, %{date: ~D[2026-02-10], balance: "1000"})
      {:ok, _} = AccountBalances.upsert(debit.id, %{date: ~D[2026-01-10], balance: "1"})
      {:ok, _} = AccountBalances.upsert(credit.id, %{date: ~D[2026-02-11], balance: "200"})

      txn(bucket(%{type: "sinking_fund"}), "contribution", "150", ~D[2026-02-01])
      txn(bucket(%{type: "sinking_fund"}), "expense", "30", ~D[2026-02-01])
      txn(bucket(%{type: "emergency_fund"}), "contribution", "50", ~D[2026-02-01])
      txn(bucket(%{monthly_budget: "500"}), "expense", "40", ~D[2026-02-05])

      d = conn |> call("View", "GET", "budget", "account_totals", %{"year" => "2026", "month" => "2"}) |> data()

      assert_dec(d["debit_total"], "1000")
      assert_dec(d["credit_total"], "200")
      assert_dec(d["sinking_total"], "150")
      assert_dec(d["emergency_total"], "50")
      assert_dec(d["current_month_expenses"], "40")
      assert_dec(d["total_money"], "600")
      assert d["account_balances_as_of"] == "2026-02-11"
    end

    test "account_history: one point per day or per month-end, clipped to `to`", %{conn: conn} do
      debit = account("debit")
      {:ok, _} = AccountBalances.upsert(debit.id, %{date: ~D[2026-01-02], balance: "10"})
      {:ok, _} = AccountBalances.upsert(debit.id, %{date: ~D[2026-02-15], balance: "20"})

      q = %{"from" => "2026-01-01", "to" => "2026-01-03"}
      assert %{"interval" => "day", "points" => points} = conn |> call("View", "GET", "budget", "account_history", q) |> data()
      assert Enum.map(points, & &1["date"]) == ~w(2026-01-01 2026-01-02 2026-01-03)
      assert Enum.map(points, &Decimal.to_integer(Decimal.round(dec(&1["total_money"])))) == [0, 10, 10]

      q = %{"from" => "2026-01-15", "to" => "2026-03-10", "interval" => "month"}
      assert %{"points" => points} = conn |> call("View", "GET", "budget", "account_history", q) |> data()
      assert Enum.map(points, & &1["date"]) == ~w(2026-01-31 2026-02-28 2026-03-10)
      assert_dec(List.last(points)["debit_total"], "20")
    end

    test "account_history rejects bad dates, bad interval and from > to", %{conn: conn} do
      for q <- [%{"from" => "nope"}, %{"to" => "2026-13-01"}, %{"interval" => "week"}, %{"from" => "2026-02-02", "to" => "2026-02-01"}] do
        assert %{"error" => _} = conn |> call("View", "GET", "budget", "account_history", q) |> json_response(400)
      end
    end

    test "balances: latest balance per account on or before date", %{conn: conn} do
      a = account("debit", "Checking")
      b = account("credit", "Visa")
      {:ok, _} = AccountBalances.upsert(a.id, %{date: ~D[2026-01-01], balance: "5"})
      {:ok, _} = AccountBalances.upsert(a.id, %{date: ~D[2026-01-20], balance: "7"})

      assert %{"as_of" => "2026-01-10", "accounts" => [checking, visa]} =
               conn |> call("View", "GET", "budget", "balances", %{"date" => "2026-01-10"}) |> data()

      assert %{"account_id" => aid, "name" => "Checking", "type" => "debit", "date" => "2026-01-01"} = checking
      assert aid == a.id
      assert_dec(checking["balance"], "5")
      assert %{"account_id" => bid, "balance" => nil, "date" => nil} = visa
      assert bid == b.id

      assert %{"error" => "date must be an ISO8601 date"} = conn |> call("View", "GET", "budget", "balances", %{"date" => "x"}) |> json_response(400)
    end

    test "PUT balance (Edit) upserts one balance per account and date", %{conn: conn} do
      a = account("debit")

      put = fn q -> call(conn, "Edit", "PUT", "budget", "balance", Map.merge(%{"account_id" => "#{a.id}"}, q)) end

      assert %{"account_id" => aid, "date" => "2026-04-01", "balance" => b} = put.(%{"balance" => "12.34", "date" => "2026-04-01"}) |> data()
      assert aid == a.id
      assert_dec(b, "12.34")

      assert %{"balance" => b} = put.(%{"balance" => "99", "date" => "2026-04-01"}) |> data()
      assert_dec(b, "99")
      assert Decimal.equal?(AccountBalances.get_by_date(a.id, ~D[2026-04-01]).balance, 99)

      today = Date.utc_today() |> Date.to_iso8601()
      assert %{"date" => ^today} = put.(%{"balance" => "1"}) |> data()
    end

    test "PUT balance validation", %{conn: conn} do
      a = account("debit")
      put = fn q -> call(conn, "Edit", "PUT", "budget", "balance", q) |> json_response(400) end

      assert %{"error" => "account_id" <> _} = put.(%{"balance" => "1"})
      assert %{"error" => "account_id" <> _} = put.(%{"account_id" => "1x", "balance" => "1"})
      assert %{"error" => "account_id" <> _} = put.(%{"account_id" => "#{a.id + 1000}", "balance" => "1"})
      assert %{"error" => "account_id" <> _} = put.(%{"account_id" => "#{a.id}", "balance" => "1", "date" => "bad"})
      assert %{"error" => "invalid balance", "errors" => %{"balance" => [_]}} = put.(%{"account_id" => "#{a.id}", "balance" => "abc"})
    end
  end
end
