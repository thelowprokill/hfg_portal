defmodule HommSaves.Repo.Migrations.CreateSaveFiles do
  use Ecto.Migration

  def change do
    create table(:save_files) do
      add :path,    :text,   null: false
      add :machine, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:save_files, [:path])
    create index(:save_files, [:updated_at])
  end
end
