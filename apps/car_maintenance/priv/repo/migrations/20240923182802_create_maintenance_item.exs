defmodule CarMaintenance.Repo.Migrations.CreateMaintenanceItem do
  use Ecto.Migration

  def change do
    create table(:maintenance_items) do
      add :car_id,          references(:cars, on_delete: :delete_all)
      add :name,            :string
      add :interval_miles,  :integer
      add :interval_months, :integer
      add :notes,           :string
      add :active,          :boolean, default: true

      add :created_by_id,   references(:users, prefix: account_prefix(Application.get_env(:car_maintenance, :env)), on_delete: :nothing)
      add :updated_by_id,   references(:users, prefix: account_prefix(Application.get_env(:car_maintenance, :env)), on_delete: :nothing)

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hfg_portal_dev"
  defp account_prefix(:test), do: "hfg_portal_test"
  defp account_prefix(_),     do: "hfg_portal"
end
