defmodule Budget.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_budget"
  prefix = case Application.compile_env(:budget, :env) do
    :dev  -> prefix <> "_dev"
    :test -> prefix <> "_test"
    _     -> prefix
  end

  @schema_prefix prefix

  @types ~w(expense contribution sinking_fund_deposit)

  schema "transactions" do
    field :amount,           :decimal
    field :description,      :string
    field :transaction_date, :date
    field :type,             :string

    belongs_to :bucket,            Budget.Buckets.Bucket
    belongs_to :scheduled_expense, Budget.ScheduledExpenses.ScheduledExpense
    belongs_to :created_by,        Budget.Users.User

    timestamps()
  end

  def changeset(transaction, attrs \\ %{}) do
    transaction
    |> cast(attrs, [
      :bucket_id,
      :scheduled_expense_id,
      :created_by_id,
      :amount,
      :description,
      :transaction_date,
      :type
    ])
    |> validate_required([:bucket_id, :amount, :description, :transaction_date, :type])
    |> validate_inclusion(:type, @types)
  end
end
