defmodule Budget.Repo.Migrations.CreateBudgetAccounts do
  use Ecto.Migration

  def change do
    create table(:budgets_accounts) do
      add :company_budget_id,     references(:company_budgets, on_delete: :delete_all)
      add :department_account_id, references(:departments_accounts, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:budgets_accounts, [:company_budget_id, :department_account_id], name: :budgets_accounts_unique_index)
    create index(:budgets_accounts, :company_budget_id)
    create index(:budgets_accounts, :department_account_id)
  end
end
