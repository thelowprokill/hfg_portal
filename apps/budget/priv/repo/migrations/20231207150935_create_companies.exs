defmodule Budget.Repo.Migrations.Companies do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :name,           :string, null: false
      add :target_balance, :decimal, precision: 12, scale: 2
      add :actual_balance, :decimal, precision: 12, scale: 2
      add :active,         :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:companies, [:name])
  end
end
