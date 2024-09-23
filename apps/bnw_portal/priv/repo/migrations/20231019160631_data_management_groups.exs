defmodule BnwPortal.Repo.Migrations.DataManagementGroups do
  use Ecto.Migration

  def change do
    create table(:data_management_groups) do
      add :name,  :string
      add :order, :integer

      timestamps()
    end
  end
end
