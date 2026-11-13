defmodule LoanRepayment.Loans.Loan do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "loan_repayment"
  prefix = case Application.compile_env(:loan_repayment, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "loans" do
    field :paid_to,       :string
    field :for,           :string
    field :description,   :string
    field :amount,        :decimal
    field :active,        :boolean, default: true

    has_one :repayment, LoanRepayment.Loans.Repayment

    belongs_to :created_by, LoanRepayment.Users.User
    belongs_to :updated_by, LoanRepayment.Users.User

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :paid_to,
      :for,
      :description,
      :amount,
      :active,
      :created_by_id,
      :updated_by_id,
    ])
  end
end
