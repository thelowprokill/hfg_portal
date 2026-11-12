defmodule Budget.AccountBalances.AccountBalance do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "budget"

  prefix =
    case Application.compile_env(:budget, :env) do
      :dev -> prefix <> "_dev"
      :test -> prefix <> "_test"
      _ -> prefix
    end

  @schema_prefix prefix

  schema "account_balances" do
    field(:account_id, :integer)
    field(:balance, :decimal, default: Decimal.new(0))
    field(:date, :date)

    belongs_to(:account, Budget.Accounts.Account, define_field: false)

    timestamps()
  end

  def changeset(account_balance, attrs \\ %{}) do
    account_balance
    |> cast(attrs, [:account_id, :balance, :date])
    |> validate_required([:account_id, :balance, :date])
    |> unique_constraint([:account_id, :date])
  end
end
