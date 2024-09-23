defmodule Budget.Repo.Migrations.CreateAnimalSexes do
  use Ecto.Migration

  def change do
    create table(:animal_sexes) do
      add :name,       :string, null: false
      add :company_id, references(:companies, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:animal_sexes, [:company_id, :name], name: :animal_sexes_unique_index)
  end
end
