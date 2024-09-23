defmodule Budget.Repo.Migrations.CreateDepartmentAccounts do
  use Ecto.Migration

  def change do
    create table(:departments_accounts) do
      add :department_id, references(:departments, on_delete: :delete_all)
      add :account_id,    references(:accounts, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:departments_accounts, [:department_id, :account_id], name: :departments_accounts_unique_index)
    create index(:departments_accounts, :department_id)
    create index(:departments_accounts, :account_id)
  end
end
