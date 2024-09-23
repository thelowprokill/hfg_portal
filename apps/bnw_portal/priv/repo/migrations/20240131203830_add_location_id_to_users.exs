defmodule BnwPortal.Repo.Migrations.AddLocationIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :location_id, :integer, after: :generic_user
    end
  end
end
