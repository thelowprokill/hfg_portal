defmodule Budget.AccountsTest do
  use Budget.DataCase

  alias Budget.{AccountBalances, Accounts}
  alias Budget.Accounts.Account
  alias Budget.AccountBalances.AccountBalance

  defp put(account, date, amount) do
    {:ok, b} = AccountBalances.upsert(account.id, %{date: date, balance: Decimal.new(amount)})
    b
  end

  describe "accounts" do
    test "changeset requires user, name and a debit/credit type" do
      assert %{user_id: [_], name: [_], type: [_]} = errors_on(Account.changeset(%Account{}, %{}))
      assert Account.changeset(%Account{}, %{user_id: 1, name: "Visa", type: "credit"}).valid?

      assert %{type: ["is invalid"]} =
               errors_on(Account.changeset(%Account{}, %{user_id: 1, name: "x", type: "savings"}))
    end

    test "list orders by name and paginates" do
      for n <- ["Visa", "Checking", "Amex"], do: account_fixture(name: n)

      assert Enum.map(Accounts.list(%{}), & &1.name) == ["Amex", "Checking", "Visa"]
      assert Enum.map(Accounts.list(%{page: 1, per_page: 2}), & &1.name) == ["Visa"]
    end

    test "create broadcasts and delete cascades to balances" do
      Accounts.subscribe()
      account = account_fixture(name: "Checking")
      assert_receive {[:account, :created], %Account{name: "Checking"}}

      {:ok, b} = AccountBalances.upsert(account.id, %{date: ~D[2026-01-01], balance: Decimal.new(5)})
      {:ok, _} = Accounts.delete(account)
      assert_receive {[:account, :deleted], _}
      assert AccountBalances.get(b.id) == nil
    end
  end

  describe "account balances" do
    setup do
      %{a: account_fixture(name: "Checking"), b: account_fixture(name: "Visa", type: "credit")}
    end

    test "changeset requires account, balance and date" do
      errors = errors_on(AccountBalance.changeset(%AccountBalance{balance: nil}, %{}))
      assert errors[:account_id] && errors[:balance] && errors[:date]
    end

    test "get_or_new returns the stored row or a fresh zero balance", %{a: a} do
      fresh = AccountBalances.get_or_new(a.id, ~D[2026-01-01])
      assert fresh.id == nil and fresh.account_id == a.id and fresh.date == ~D[2026-01-01]
      assert dec_eq?(fresh.balance, 0)

      stored = put(a, ~D[2026-01-01], "12.34")
      assert AccountBalances.get_or_new(a.id, ~D[2026-01-01]).id == stored.id
      assert AccountBalances.get_by_date(a.id, ~D[2026-01-02]) == nil
    end

    test "upsert updates the same row for the same day and makes a new one for another day", %{a: a} do
      AccountBalances.subscribe()
      first = put(a, ~D[2026-01-01], "100")
      assert_receive {[:account_balance, :created], _}

      again = put(a, ~D[2026-01-01], "150.50")
      assert_receive {[:account_balance, :updated], _}
      assert again.id == first.id
      assert dec_eq?(AccountBalances.get(first.id).balance, "150.50")

      other = put(a, ~D[2026-01-02], "1")
      assert other.id != first.id
    end

    test "upsert defaults the date to today", %{a: a} do
      {:ok, b} = AccountBalances.upsert(a.id, %{balance: Decimal.new(7)})
      assert b.date == Date.utc_today()
    end

    test "the database refuses a second row for the same account and day", %{a: a} do
      put(a, ~D[2026-01-01], "1")

      assert {:error, cs} =
               AccountBalances.create_or_update(AccountBalances.new(), %{account_id: a.id, date: ~D[2026-01-01], balance: 2})

      assert %{account_id: ["has already been taken"]} = errors_on(cs)
    end

    test "negative balances (credit card debt) are kept", %{b: b} do
      put(b, ~D[2026-01-01], "-250.75")
      assert dec_eq?(AccountBalances.map_for_date(~D[2026-01-01])[b.id], "-250.75")
    end

    test "map_for_date carries forward the latest balance on or before the date", %{a: a, b: b} do
      put(a, ~D[2026-01-10], "10")
      put(a, ~D[2026-01-20], "20")
      put(b, ~D[2026-01-15], "-5")

      assert AccountBalances.map_for_date(~D[2026-01-09]) == %{}

      m = AccountBalances.map_for_date(~D[2026-01-10])
      assert Map.keys(m) == [a.id]
      assert dec_eq?(m[a.id], "10")

      m = AccountBalances.map_for_date(~D[2026-01-19])
      assert dec_eq?(m[a.id], "10")
      assert dec_eq?(m[b.id], "-5")

      assert dec_eq?(AccountBalances.map_for_date(~D[2026-06-01])[a.id], "20")

      assert AccountBalances.dates_for_date(~D[2026-01-19]) == %{a.id => ~D[2026-01-10], b.id => ~D[2026-01-15]}
    end

    test "map_for_month uses the last day of the month, leap years included", %{a: a} do
      put(a, ~D[2024-02-29], "29")
      put(a, ~D[2024-03-01], "1")

      assert dec_eq?(AccountBalances.map_for_month(2024, 2)[a.id], "29")
      assert AccountBalances.map_for_month(2024, 1) == %{}
      assert dec_eq?(AccountBalances.map_for_month(2024, 3)[a.id], "1")
    end

    test "latest dates across all accounts", %{a: a, b: b} do
      assert AccountBalances.latest_date_as_of(~D[2026-12-31]) == nil
      assert AccountBalances.latest_date_for_month(2026, 1) == nil

      put(a, ~D[2026-01-05], "1")
      put(b, ~D[2026-01-31], "1")
      put(a, ~D[2026-02-01], "1")

      assert AccountBalances.latest_date_as_of(~D[2026-01-30]) == ~D[2026-01-05]
      assert AccountBalances.latest_date_for_month(2026, 1) == ~D[2026-01-31]
      assert AccountBalances.latest_date_for_month(2026, 12) == ~D[2026-02-01]
    end
  end
end
