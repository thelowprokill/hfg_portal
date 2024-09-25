defmodule LoanRepayment.Repo.Migrations.Repayment do
  use Ecto.Migration

  def change do
    create table(:repayment) do
      add :loan_id,           references(:loans)
      add :paid_amount,       :decimal, precision: 12, scale: 2
      add :paid_amount_tot,   :decimal, precision: 12, scale: 2
      add :remaining_balance, :decimal, precision: 12, scale: 2

      add :created_by_id, references(:users, prefix: account_prefix(Application.get_env(:loan_repayment, :env)), on_delete: :nothing)
      add :updated_by_id, references(:users, prefix: account_prefix(Application.get_env(:loan_repayment, :env)), on_delete: :nothing)

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hfg_portal_dev"
  defp account_prefix(:test), do: "hfg_portal_test"
  defp account_prefix(_),     do: "hfg_portal"
end
