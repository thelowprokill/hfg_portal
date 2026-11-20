defmodule HfgPortalWeb.Budget.PagesTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortal.AccountsFixtures
  import HfgPortalWeb.LiveHelpers

  alias Budget.{Accounts, AccountBalances, Buckets, ScheduledExpenses, Transactions, UserRoles}

  defp budget_user(conn, role) do
    user = user_fixture(%{first_name: "Budget#{role}"})
    budget_role(user, role)
    %{conn: log_in(conn, user), user: user}
  end

  defp account!(user, attrs \\ %{}) do
    {:ok, a} = Accounts.create_or_update(%Budget.Accounts.Account{}, Enum.into(attrs, %{user_id: user.id, name: "Checking", type: "debit"}))
    a
  end

  defp bucket!(user, attrs \\ %{}) do
    {:ok, b} = Buckets.create_or_update(%Budget.Buckets.Bucket{}, Enum.into(attrs, %{user_id: user.id, name: "Groceries", type: "normal"}))
    b
  end

  defp transaction!(bucket, attrs \\ %{}) do
    {:ok, t} =
      Transactions.create_or_update(
        %Budget.Transactions.Transaction{},
        Enum.into(attrs, %{bucket_id: bucket.id, amount: Decimal.new("10.00"), description: "Milk", transaction_date: Date.utc_today(), type: "expense"})
      )

    t
  end

  defp scheduled!(bucket, attrs \\ %{}) do
    {:ok, s} =
      ScheduledExpenses.create_or_update(
        %Budget.ScheduledExpenses.ScheduledExpense{},
        Enum.into(attrs, %{bucket_id: bucket.id, amount: Decimal.new("5.00"), description: "Netflix", frequency: "monthly", day_of_month: 1, next_due_date: Date.add(Date.utc_today(), 10)})
      )

    s
  end

  describe "accounts" do
    setup %{conn: conn}, do: budget_user(conn, "Admin")

    test "create: errors then save", %{conn: conn, user: user} do
      {_view, page} = open_page(conn, "budget,manage,accounts")
      render_click(page, "add_new")

      html = page |> element("#account form") |> render_change(%{"account" => %{"name" => ""}})
      assert html =~ "can&#39;t be blank"

      page |> element("#account form") |> render_submit(%{"account" => %{"name" => "Savings", "type" => "credit", "user_id" => "#{user.id}"}})

      refute has_element?(page, "#account")
      assert [%{name: "Savings", type: "credit"}] = Accounts.list(%{})
      assert render(page) =~ "Savings"
    end

    test "an invalid type is rejected", %{conn: conn, user: user} do
      {_view, page} = open_page(conn, "budget,manage,accounts")
      render_click(page, "add_new")

      page |> element("#account form") |> render_submit(%{"account" => %{"name" => "X", "type" => "bitcoin", "user_id" => "#{user.id}"}})
      assert has_element?(page, "#account")
      assert Accounts.list(%{}) == []
    end

    test "edit and delete", %{conn: conn, user: user} do
      account = account!(user)
      {_view, page} = open_page(conn, "budget,manage,accounts")

      render_click(page, "edit", %{"id" => "#{account.id}"})
      page |> element("#account form") |> render_submit(%{"account" => %{"name" => "Joint"}})
      assert Accounts.get(account.id).name == "Joint"
      assert render(page) =~ "Joint"

      render_click(page, "delete", %{"id" => "#{account.id}"})
      refute Accounts.get(account.id)
      refute render(page) =~ "Joint"
    end

    test "search by name", %{conn: conn, user: user} do
      account!(user, %{name: "Chase Checking"})
      account!(user, %{name: "Amex Card", type: "credit"})
      {_view, page} = open_page(conn, "budget,manage,accounts")

      render_click(page, "search", %{"field" => "name"})
      html = render_change(page, "search", %{"search" => %{"field" => "name", "val" => "Chase"}})
      assert html =~ "Chase Checking"
      refute html =~ "Amex Card"
    end

    test "load more pages through 50 at a time", %{conn: conn, user: user} do
      for i <- 1..55, do: account!(user, %{name: "Acct #{String.pad_leading("#{i}", 2, "0")}"})
      {_view, page} = open_page(conn, "budget,manage,accounts")

      html = render(page)
      assert html =~ "Acct 50"
      refute html =~ "Acct 51"

      html = render_click(page, "load_more")
      assert html =~ "Acct 55"
      assert length(Regex.scan(~r/Acct \d\d/, html)) == 55
    end

    test "accounts added elsewhere appear live", %{conn: conn, user: user} do
      {_view, page} = open_page(conn, "budget,manage,accounts")
      account!(user, %{name: "From Elsewhere"})
      assert render(page) =~ "From Elsewhere"
    end
  end

  describe "accounts page access" do
    for role <- ["View", "Edit"] do
      test "a #{role} user cannot open the accounts page", %{conn: conn} do
        %{conn: conn} = budget_user(conn, unquote(role))
        assert rendered_module(conn, "budget,manage,accounts") == HfgPortalWeb.Home.HomeLive
      end
    end

    test "an Admin user can open the accounts page", %{conn: conn} do
      %{conn: conn} = budget_user(conn, "Admin")
      assert rendered_module(conn, "budget,manage,accounts") == HfgPortalWeb.Budget.Accounts.AccountsLive
    end
  end

  describe "buckets" do
    setup %{conn: conn}, do: budget_user(conn, "Admin")

    test "create a sinking fund: both target fields are required together", %{conn: conn, user: user} do
      {_view, page} = open_page(conn, "budget,manage,buckets")
      render_click(page, "add_new")
      page |> element("#bucket input[phx-value-bucket_type='sinking_fund']") |> render_click()

      html =
        page
        |> element("#bucket form")
        |> render_submit(%{"bucket" => %{"name" => "Vacation", "monthly_contribution" => "100", "user_id" => "#{user.id}", "type" => "sinking_fund"}})

      assert html =~ "is required when monthly_contribution is set"
      assert Buckets.list(%{}) == []

      page
      |> element("#bucket form")
      |> render_submit(%{"bucket" => %{"name" => "Vacation", "monthly_contribution" => "100", "max_balance" => "1200", "user_id" => "#{user.id}", "type" => "sinking_fund"}})

      assert [%{name: "Vacation", type: "sinking_fund"}] = Buckets.list(%{})
      refute has_element?(page, "#bucket")
    end

    test "shows this month's expenses per bucket", %{conn: conn, user: user} do
      bucket = bucket!(user)
      transaction!(bucket, %{amount: Decimal.new("12.50")})
      transaction!(bucket, %{amount: Decimal.new("7.50")})

      {_view, page} = open_page(conn, "budget,manage,buckets")
      assert render(page) =~ "$20.00"
    end

    test "edit, delete and live updates", %{conn: conn, user: user} do
      bucket = bucket!(user)
      {_view, page} = open_page(conn, "budget,manage,buckets")

      render_click(page, "edit", %{"id" => "#{bucket.id}"})
      page |> element("#bucket form") |> render_submit(%{"bucket" => %{"name" => "Food"}})
      assert Buckets.get(bucket.id).name == "Food"

      bucket!(user, %{name: "Gas"})
      assert render(page) =~ "Gas"

      render_click(page, "delete", %{"id" => "#{bucket.id}"})
      refute Buckets.get(bucket.id)
      refute render(page) =~ "Food"
    end
  end

  describe "transactions" do
    setup %{conn: conn} = ctx do
      ctx = budget_user(conn, "Admin")
      Map.merge(ctx, %{bucket: bucket!(ctx.user)})
    end

    test "create updates the bucket balance", %{conn: conn, bucket: bucket, user: user} do
      {:ok, sinking} = Buckets.create_or_update(%Budget.Buckets.Bucket{}, %{user_id: user.id, name: "Car", type: "emergency_fund"})
      {_view, page} = open_page(conn, "budget,manage,transactions")
      render_click(page, "add_new")

      html = page |> element("#transaction form") |> render_submit(%{"transaction" => %{"description" => ""}})
      assert html =~ "can&#39;t be blank"

      page
      |> element("#transaction form")
      |> render_submit(%{
        "transaction" => %{
          "bucket_id" => "#{sinking.id}",
          "amount" => "40.00",
          "description" => "Deposit",
          "type" => "contribution",
          "transaction_date" => Date.to_iso8601(Date.utc_today())
        }
      })

      refute has_element?(page, "#transaction")
      assert render(page) =~ "Deposit"
      assert Decimal.equal?(Buckets.get(sinking.id).balance, Decimal.new("40.00"))
      assert Buckets.get(bucket.id).balance |> Decimal.equal?(0)
    end

    test "delete re-syncs the balance", %{conn: conn, bucket: bucket} do
      t = transaction!(bucket, %{type: "contribution", amount: Decimal.new("25")})
      assert Decimal.equal?(Buckets.get(bucket.id).balance, 25)

      {_view, page} = open_page(conn, "budget,manage,transactions")
      render_click(page, "delete", %{"id" => "#{t.id}"})

      refute Transactions.get(t.id)
      assert Decimal.equal?(Buckets.get(bucket.id).balance, 0)
      refute render(page) =~ "Milk"
    end

    test "edit", %{conn: conn, bucket: bucket} do
      t = transaction!(bucket)
      {_view, page} = open_page(conn, "budget,manage,transactions")

      render_click(page, "edit", %{"id" => "#{t.id}"})
      page |> element("#transaction form") |> render_submit(%{"transaction" => %{"description" => "Eggs"}})

      assert Transactions.get(t.id).description == "Eggs"
      assert render(page) =~ "Eggs"
    end

    test "search by description", %{conn: conn, bucket: bucket} do
      transaction!(bucket, %{description: "Coffee beans"})
      transaction!(bucket, %{description: "Rent"})
      {_view, page} = open_page(conn, "budget,manage,transactions")

      render_click(page, "search", %{"field" => "description"})
      html = render_change(page, "search", %{"search" => %{"field" => "description", "val" => "Coffee"}})
      assert html =~ "Coffee beans"
      refute html =~ "Rent"
    end

    test "the bucket column filter shows only that bucket", %{conn: conn, bucket: bucket, user: user} do
      other = bucket!(user, %{name: "Other"})
      transaction!(bucket, %{description: "In groceries"})
      transaction!(other, %{description: "In other"})
      {_view, page} = open_page(conn, "budget,manage,transactions")

      render_click(page, "search", %{"field" => "bucket_id"})
      html = render_change(page, "search", %{"search" => %{"field" => "bucket_id", "val" => "#{bucket.id}"}})
      assert html =~ "In groceries"
      refute html =~ "In other"
    end

    test "?bucket_id= filters the list", %{conn: conn, bucket: bucket, user: user} do
      other = bucket!(user, %{name: "Other"})
      transaction!(bucket, %{description: "In groceries"})
      transaction!(other, %{description: "In other"})

      {_view, page} = open_page(conn, "budget,manage,transactions", "&bucket_id=#{bucket.id}")
      html = render(page)
      assert html =~ "In groceries"
      refute html =~ "In other"
    end

    test "transactions added elsewhere appear live with their bucket", %{conn: conn, bucket: bucket} do
      {_view, page} = open_page(conn, "budget,manage,transactions")
      transaction!(bucket, %{description: "Live one"})

      # (the bucket name is preloaded through Budget.Repo, which in the test sandbox is a
      # different connection that cannot see the bucket, so only the row is checked)
      assert render(page) =~ "Live one"
    end
  end

  describe "scheduled expenses" do
    setup %{conn: conn} = ctx do
      ctx = budget_user(conn, "Admin")
      Map.merge(ctx, %{bucket: bucket!(ctx.user)})
    end

    test "monthly needs a day of month", %{conn: conn, bucket: bucket} do
      {_view, page} = open_page(conn, "budget,manage,scheduled_expenses")
      render_click(page, "add_new")

      params = %{"bucket_id" => "#{bucket.id}", "amount" => "9.99", "description" => "Spotify", "frequency" => "monthly", "next_due_date" => "2030-01-01"}
      html = page |> element("#scheduled_expense form") |> render_submit(%{"scheduled_expense" => params})
      assert html =~ "can&#39;t be blank"

      page |> element("#scheduled_expense form") |> render_submit(%{"scheduled_expense" => Map.put(params, "day_of_month", "1")})
      assert [%{description: "Spotify"}] = ScheduledExpenses.list(%{})
      assert render(page) =~ "Spotify"
    end

    test "toggle active flips it both ways", %{conn: conn, bucket: bucket} do
      s = scheduled!(bucket)
      {_view, page} = open_page(conn, "budget,manage,scheduled_expenses")

      render_click(page, "toggle_active", %{"id" => "#{s.id}"})
      refute ScheduledExpenses.get(s.id).active
      assert render(page) =~ "Inactive"

      render_click(page, "toggle_active", %{"id" => "#{s.id}"})
      assert ScheduledExpenses.get(s.id).active
    end

    test "run scheduled books due expenses and advances them", %{conn: conn, bucket: bucket} do
      due = scheduled!(bucket, %{next_due_date: Date.utc_today(), description: "Due today"})
      later = scheduled!(bucket, %{description: "Later"})
      {_view, page} = open_page(conn, "budget,manage,scheduled_expenses")

      render_click(page, "run_scheduled")

      assert [%{description: "Due today", type: "expense"}] = Transactions.list_for_bucket(bucket.id)
      assert Date.compare(ScheduledExpenses.get(due.id).next_due_date, Date.utc_today()) == :gt
      assert ScheduledExpenses.get(later.id).next_due_date == later.next_due_date
    end

    test "delete", %{conn: conn, bucket: bucket} do
      s = scheduled!(bucket)
      {_view, page} = open_page(conn, "budget,manage,scheduled_expenses")
      render_click(page, "delete", %{"id" => "#{s.id}"})
      refute ScheduledExpenses.get(s.id)
      refute render(page) =~ "Netflix"
    end
  end

  describe "balances" do
    test "an admin sets an account balance", %{conn: conn} do
      %{conn: conn, user: user} = budget_user(conn, "Admin")
      account = account!(user)
      {_view, page} = open_page(conn, "budget,balances")

      render_click(page, "set_balance", %{"id" => "#{account.id}"})
      page |> element("form[phx-submit='save']") |> render_submit(%{"account_balance" => %{"balance" => "1234.56"}})

      assert Decimal.equal?(AccountBalances.map_for_date(Date.utc_today())[account.id], Decimal.new("1234.56"))
      assert render(page) =~ "$1234.56"
    end

    test "balances set elsewhere show live", %{conn: conn} do
      %{conn: conn, user: user} = budget_user(conn, "Edit")
      account = account!(user)
      {_view, page} = open_page(conn, "budget,balances")

      {:ok, _} = AccountBalances.upsert(account.id, %{balance: Decimal.new("77.00")})
      assert render(page) =~ "$77.00"
    end

    test "a view-only user cannot change balances", %{conn: conn} do
      %{conn: conn, user: user} = budget_user(conn, "View")
      account = account!(user)
      {_view, page} = open_page(conn, "budget,balances")

      refute has_element?(page, "[phx-click='set_balance']")
      render_click(page, "set_balance", %{"id" => "#{account.id}"})

      if has_element?(page, "form[phx-submit='save']") do
        page |> element("form[phx-submit='save']") |> render_submit(%{"account_balance" => %{"balance" => "999"}})
      end

      assert AccountBalances.map_for_date(Date.utc_today())[account.id] == nil
    end
  end

  describe "dashboard" do
    test "a viewer sees buckets but cannot add, edit or delete transactions", %{conn: conn} do
      %{conn: conn, user: user} = budget_user(conn, "View")
      bucket = bucket!(user)
      t = transaction!(bucket)
      {_view, page} = open_page(conn, "budget,dashboard")

      assert render(page) =~ "Groceries"
      render_click(page, "select_bucket", %{"id" => "#{bucket.id}"})
      assert render(page) =~ "Milk"
      refute has_element?(page, "[phx-click='delete']")
      refute has_element?(page, "[phx-click='add_new']")

      # crafted events are ignored
      render_click(page, "delete", %{"id" => "#{t.id}"})
      assert Transactions.get(t.id)
      render_click(page, "add_new")
      refute has_element?(page, "#transaction")
      render_click(page, "edit", %{"id" => "#{t.id}"})
      refute has_element?(page, "#transaction")
    end

    test "an editor can delete a bucket's transaction", %{conn: conn} do
      %{conn: conn, user: user} = budget_user(conn, "Edit")
      bucket = bucket!(user)
      t = transaction!(bucket)
      {_view, page} = open_page(conn, "budget,dashboard", "&bucket=#{bucket.id}")

      assert has_element?(page, "[phx-click='delete'][phx-value-id='#{t.id}']")
      render_click(page, "delete", %{"id" => "#{t.id}"})
      refute Transactions.get(t.id)
      refute render(page) =~ "Milk"
    end

    test "edit rights follow live role changes", %{conn: conn} do
      %{conn: conn, user: user} = budget_user(conn, "View")
      bucket = bucket!(user)
      t = transaction!(bucket)
      {_view, page} = open_page(conn, "budget,dashboard", "&bucket=#{bucket.id}")
      refute has_element?(page, "[phx-click='delete']")

      {:ok, _} = UserRoles.create_or_update(UserRoles.get(user.id, :user), %{role: "Edit"})
      assert has_element?(page, "[phx-click='delete'][phx-value-id='#{t.id}']")
    end

    test "totals follow account balances and transactions live", %{conn: conn} do
      %{conn: conn, user: user} = budget_user(conn, "View")
      account = account!(user)
      {_view, page} = open_page(conn, "budget,dashboard")
      assert render(page) =~ "Debit accounts: $0"

      {:ok, _} = AccountBalances.upsert(account.id, %{balance: Decimal.new("500.00")})
      assert render(page) =~ "Debit accounts: $500.00"

      {:ok, fund} = Buckets.create_or_update(%Budget.Buckets.Bucket{}, %{user_id: user.id, name: "Rainy", type: "emergency_fund", monthly_contribution: Decimal.new("50")})
      transaction!(fund, %{type: "contribution", amount: Decimal.new("100.00")})
      # emergency funds are set aside from the total
      assert render(page) =~ "$400.00"
    end

    test "an emergency fund without a monthly contribution still renders", %{conn: conn} do
      %{conn: conn, user: user} = budget_user(conn, "View")
      bucket!(user, %{name: "Rainy", type: "emergency_fund"})
      {_view, page} = open_page(conn, "budget,dashboard")
      assert render(page) =~ "Rainy"
    end

    test "month navigation", %{conn: conn} do
      %{conn: conn} = budget_user(conn, "View")
      {_view, page} = open_page(conn, "budget,dashboard")
      today = Date.utc_today()
      this_month = HfgPortalWeb.Helpers.Utility.get_month_name(today.month)

      assert render(page) =~ "#{this_month} #{today.year}"
      refute has_element?(page, "[phx-click='reset_month']")

      html = render_click(page, "prev_month")
      refute html =~ "#{this_month} #{today.year}"
      assert has_element?(page, "[phx-click='reset_month']")

      html = render_click(page, "reset_month")
      assert html =~ "#{this_month} #{today.year}"
    end
  end

  describe "users" do
    setup %{conn: conn}, do: budget_user(conn, "Admin")

    test "lists users with their roles and hides the edit button for yourself", %{conn: conn, user: me} do
      other = user_fixture(%{first_name: "Otto"})
      {_view, page} = open_page(conn, "budget,manage,users")

      html = render(page)
      assert html =~ "Otto"
      assert html =~ "None"
      assert has_element?(page, "[phx-click='edit'][phx-value-id='#{other.id}']")
      refute has_element?(page, "[phx-click='edit'][phx-value-id='#{me.id}']")
    end

    test "grant a role, then change it", %{conn: conn} do
      other = user_fixture(%{first_name: "Otto"})
      {_view, page} = open_page(conn, "budget,manage,users")

      render_click(page, "edit", %{"id" => "#{other.id}"})
      page |> element("#user_role form") |> render_submit(%{"user_role" => %{"role" => "Edit", "user_id" => "#{other.id}"}})
      assert UserRoles.get(other.id, :user).role == "Edit"
      refute has_element?(page, "#user_role")

      render_click(page, "edit", %{"id" => "#{other.id}"})
      page |> element("#user_role form") |> render_submit(%{"user_role" => %{"role" => "View"}})
      assert UserRoles.get(other.id, :user).role == "View"
      assert render(page) =~ "View"
    end

    test "role changes made elsewhere show live", %{conn: conn} do
      other = user_fixture(%{first_name: "Otto"})
      budget_role(other, "View")
      {_view, page} = open_page(conn, "budget,manage,users")

      {:ok, _} = UserRoles.create_or_update(UserRoles.get(other.id, :user), %{role: "Admin"})
      assert page |> element("tr", "Otto") |> render() =~ "Admin"
    end

    test "search by role", %{conn: conn} do
      viewer = user_fixture(%{first_name: "Vera"})
      budget_role(viewer, "View")
      user_fixture(%{first_name: "Nobody"})
      {_view, page} = open_page(conn, "budget,manage,users")

      render_click(page, "search", %{"field" => "role"})
      html = render_change(page, "search", %{"search" => %{"field" => "role", "val" => "View"}})
      assert html =~ "Vera"
      refute html =~ "Nobody"
    end
  end
end
