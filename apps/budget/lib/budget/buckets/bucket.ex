defmodule Budget.Buckets.Bucket do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_budget"
  prefix = case Application.compile_env(:budget, :env) do
    :dev  -> prefix <> "_dev"
    :test -> prefix <> "_test"
    _     -> prefix
  end

  @schema_prefix prefix

  schema "buckets" do
    field :user_id,              :integer
    field :name,                 :string
    field :description,          :string
    field :balance,              :decimal, default: Decimal.new(0)
    field :monthly_budget,       :decimal
    field :monthly_contribution, :decimal
    field :max_balance,          :decimal

    has_many :transactions,       Budget.Transactions.Transaction
    has_many :scheduled_expenses, Budget.ScheduledExpenses.ScheduledExpense

    timestamps()
  end

  def changeset(bucket, attrs \\ %{}) do
    bucket
    |> cast(attrs, [
      :user_id,
      :name,
      :description,
      :balance,
      :monthly_budget,
      :monthly_contribution,
      :max_balance
    ])
    |> validate_required([:user_id, :name])
    |> validate_sinking_fund_fields()
  end

  defp validate_sinking_fund_fields(changeset) do
    contribution = get_field(changeset, :monthly_contribution)
    max_balance  = get_field(changeset, :max_balance)

    cond do
      not is_nil(contribution) and is_nil(max_balance) ->
        add_error(changeset, :max_balance, "is required when monthly_contribution is set")

      is_nil(contribution) and not is_nil(max_balance) ->
        add_error(changeset, :monthly_contribution, "is required when max_balance is set")

      true ->
        changeset
    end
  end
end
