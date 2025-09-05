defmodule CarMaintenance.Repo.Migrations.CreateMaintenanceImages do
  use Ecto.Migration

  def change do
    create table(:maintenance_images) do
      add :name,                :string
      add :service_history_id,  references(:service_history, on_delete: :delete_all)
      add :image,               :binary
      add :image_content_type,  :string
      add :created_by_id,       references(:users, prefix: account_prefix(Application.get_env(:car_maintenance, :env)), on_delete: :delete_all)
      add :updated_by_id,       references(:users, prefix: account_prefix(Application.get_env(:car_maintenance, :env)), on_delete: :delete_all)

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hfg_portal_dev"
  defp account_prefix(:test), do: "hfg_portal_test"
  defp account_prefix(_),     do: "hfg_portal"
end
