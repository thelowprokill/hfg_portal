defmodule BnwPortal.Repo.Migrations.CreateLocations do
  use Ecto.Migration

  def change do
    create table(:locations) do
      add :name,       :string
      add :short_name, :string
      add :active,     :boolean, default: true

      timestamps()
    end
  end
end
