defmodule LoanRepayment.Loans.Repayment do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_loan_repayment"
  prefix = case Application.compile_env(:loan_repayment, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "repayment" do
    field :paid_amount,       :decimal
    field :paid_amount_tot,   :decimal
    field :remaining_balance, :decimal

    field :last_paid_amount,  :decimal, virtual: true
    field :loan_amount,       :decimal, virtual: true

    belongs_to :loan, LoanRepayment.Loans.Loan

    belongs_to :created_by, LoanRepayment.Users.User
    belongs_to :updated_by, LoanRepayment.Users.User

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :loan_id,
      :paid_amount,      
      :paid_amount_tot,  
      :remaining_balance,
      :last_paid_amount,
      :loan_amount,
      :created_by_id,
      :updated_by_id,
    ])
    |> calculate_amounts()
  end

  defp calculate_amounts(changeset) do
    paid_amount      = get_field(changeset, :paid_amount)
    loan_amount      = get_field(changeset, :loan_amount)
    last_paid_amount = get_field(changeset, :last_paid_amount)

    cond do
      paid_amount && last_paid_amount && loan_amount ->
        changeset
        |> put_change(:paid_amount_tot,   Decimal.add(paid_amount, last_paid_amount))
        |> put_change(:remaining_balance, Decimal.sub(loan_amount, Decimal.add(paid_amount, last_paid_amount)))
      paid_amount && loan_amount ->
        changeset
        |> put_change(:paid_amount_tot,   paid_amount)
        |> put_change(:remaining_balance, Decimal.sub(loan_amount, paid_amount))
      true -> 
        changeset
        |> put_change(:paid_amount_tot,   paid_amount)
    end
  end
end
