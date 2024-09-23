defmodule Budget.Repo.Migrations.Locations do
  use Ecto.Migration

  def change do
    create table(:locations) do
      add :name,          :string, null: false
      add :yard_number,   :string
      add :external_code, :string, null: false
      add :company_id,    references(:companies, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:locations, [:name, :company_id], name: :companies_unique_index)
    create unique_index(:locations, [:name, :company_id, :yard_number, :external_code], name: :companies_unique_index_all)
  end
end
