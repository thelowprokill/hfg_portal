defmodule Budget.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Budget.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Budget.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Budget.DataCase
    end
  end

  setup tags do
    Budget.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    # The budget contexts read and write through HfgPortal.Repo (see DefaultCrud), so both are checked out.
    for repo <- [Budget.Repo, HfgPortal.Repo] do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(repo, shared: not tags[:async])
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    end
  end

  @doc "Inserts a hfg_portal user (the budget app only reads them)."
  def user_fixture(attrs \\ %{}) do
    %HfgPortal.Accounts.User{
      username: "user#{System.unique_integer([:positive])}",
      hashed_password: "not-a-real-hash",
      active: true
    }
    |> struct!(attrs)
    |> HfgPortal.Repo.insert!()
  end

  def bucket_fixture(attrs \\ %{}) do
    {:ok, bucket} =
      Budget.Buckets.create_or_update(
        Budget.Buckets.new(),
        Enum.into(attrs, %{user_id: 1, name: "Bucket #{System.unique_integer([:positive])}"})
      )

    bucket
  end

  def transaction_fixture(attrs) do
    {:ok, t} =
      Budget.Transactions.create_or_update(
        Budget.Transactions.new(),
        Enum.into(attrs, %{
          amount: Decimal.new("10.00"),
          description: "tx",
          transaction_date: ~D[2026-03-15],
          type: "expense"
        })
      )

    t
  end

  def scheduled_expense_fixture(attrs) do
    {:ok, se} =
      Budget.ScheduledExpenses.create_or_update(
        Budget.ScheduledExpenses.new(),
        Enum.into(attrs, %{
          amount: Decimal.new("25.00"),
          description: "Netflix",
          frequency: "monthly",
          day_of_month: 15,
          next_due_date: ~D[2026-03-15]
        })
      )

    se
  end

  def account_fixture(attrs \\ %{}) do
    {:ok, account} =
      Budget.Accounts.create_or_update(
        Budget.Accounts.new(),
        Enum.into(attrs, %{user_id: 1, name: "Account #{System.unique_integer([:positive])}", type: "debit"})
      )

    account
  end

  @doc "Decimal equality that ignores scale (10 == 10.00)."
  def dec_eq?(a, b), do: Decimal.equal?(a, Decimal.new(b))

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
