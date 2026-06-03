defmodule Budget.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @types ~w(expense contribution sinking_fund_deposit)

  schema "transactions" do
    field :amount,           :decimal
    field :description,      :string
    field :transaction_date, :date
    field :type,             :string

    belongs_to :bucket,            Budget.Buckets.Bucket
    belongs_to :scheduled_expense, Budget.ScheduledExpenses.ScheduledExpense

    timestamps()
  end

  def changeset(transaction, attrs \\ %{}) do
    transaction
    |> cast(attrs, [
      :bucket_id,
      :scheduled_expense_id,
      :amount,
      :description,
      :transaction_date,
      :type
    ])
    |> validate_required([:bucket_id, :amount, :description, :transaction_date, :type])
    |> validate_inclusion(:type, @types)
  end
end
