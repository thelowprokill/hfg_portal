defmodule LoanRepayment.Repo.Migrations.Loans do
  use Ecto.Migration

  def change do
    execute("CREATE SCHEMA IF NOT EXISTS \"#{Application.get_env(:loan_repayment, LoanRepayment.Repo)[:migration_default_prefix]}\"", "")

    create table(:loans) do
      add :paid_to,       :string
      add :for,           :string
      add :description,   :string
      add :amount,        :decimal, precision: 12, scale: 2

      add :active,        :boolean, default: true
      add :created_by_id, references(:users, prefix: account_prefix(Application.get_env(:loan_repayment, :env)), on_delete: :nothing)
      add :updated_by_id, references(:users, prefix: account_prefix(Application.get_env(:loan_repayment, :env)), on_delete: :nothing)

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hfg_portal_dev"
  defp account_prefix(:test), do: "hfg_portal_test"
  defp account_prefix(_),     do: "hfg_portal"
end
