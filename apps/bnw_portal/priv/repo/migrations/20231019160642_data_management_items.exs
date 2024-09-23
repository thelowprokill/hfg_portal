defmodule BnwPortal.Repo.Migrations.DataManagementItems do
  use Ecto.Migration

  def change do
    create table(:data_management_items) do
      add :name,     :string
      add :link,     :string
      add :order,    :integer
      add :new_tab,  :boolean
      add :group_id, references(:data_management_groups, on_delete: :delete_all)

      timestamps()
    end
  end
end
