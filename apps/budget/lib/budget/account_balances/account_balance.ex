defmodule Budget.AccountBalances.AccountBalance do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_budget"

  prefix =
    case Application.compile_env(:budget, :env) do
      :dev -> prefix <> "_dev"
      :test -> prefix <> "_test"
      _ -> prefix
    end

  @schema_prefix prefix

  schema "account_balances" do
    field(:account_id, :integer)
    field(:year, :integer)
    field(:month, :integer)
    field(:balance, :decimal, default: Decimal.new(0))

    belongs_to(:account, Budget.Accounts.Account, define_field: false)

    timestamps()
  end

  def changeset(account_balance, attrs \\ %{}) do
    account_balance
    |> cast(attrs, [:account_id, :year, :month, :balance])
    |> validate_required([:account_id, :year, :month, :balance])
    |> validate_number(:month, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> unique_constraint([:account_id, :year, :month])
  end
end
