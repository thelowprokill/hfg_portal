defmodule Budget.Repo.Migrations.CreateAnimalTypes do
  use Ecto.Migration

  def change do
    create table(:animal_types) do
      add :name,       :string, null: false
      add :company_id, references(:companies, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:animal_types, [:company_id, :name], name: :animal_types_unique_index)
  end
end
