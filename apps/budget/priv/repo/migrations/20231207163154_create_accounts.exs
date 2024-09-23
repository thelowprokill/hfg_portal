defmodule Budget.Repo.Migrations.Accounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :name,           :string, null: false
      add :account_number, :string, null: false
      add :external_id,    :bigint
      add :type,           :string
      add :active,         :boolean, default: true, null: false
      add :company_id,     references(:companies, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:accounts, [:company_id, :account_number, :name], name: :accounts_unique_index)
    create unique_index(:accounts, [:company_id, :name], name: :accounts_unique_name_index)
    create unique_index(:accounts, [:company_id, :account_number], name: :accounts_unique_number_index)
  end
end
