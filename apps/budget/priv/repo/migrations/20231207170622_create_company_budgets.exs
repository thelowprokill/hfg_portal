defmodule Budget.Repo.Migrations.CreateCompanyBudgets do
  use Ecto.Migration

  def change do
    create table(:company_budgets) do
      add :name,            :string, null: false
      add :active,          :boolean, default: true, null: false
      add :starting_month,  :tinyint, default: 1, null: false
      add :target_balance,  :decimal, precision: 12, scale: 2
      add :actual_balance,  :decimal, precision: 12, scale: 2
      add :company_percent, :decimal, precision: 12, scale: 2
      add :company_id,      references(:companies, on_delete: :delete_all)
      add :location_id,     references(:locations, on_delete: :restrict)

      timestamps()
    end

    create unique_index(:company_budgets, [:name, :company_id])
  end
end
