defmodule CarMaintenance.Repo.Migrations.CreateServiceHistory do
  use Ecto.Migration

  def change do
    create table(:service_history) do
      add :car_id,              references(:cars, on_delete: :nothing)
      add :maintenance_item_id, references(:maintenance_items, on_delete: :nothing)
      add :service_date,        :date
      add :mileage,             :integer
      add :name,                :string
      add :named_item,          :boolean, default: false
      add :notes,               :string

      add :created_by_id,   references(:users, prefix: account_prefix(Application.get_env(:car_maintenance, :env)), on_delete: :nothing)
      add :updated_by_id,   references(:users, prefix: account_prefix(Application.get_env(:car_maintenance, :env)), on_delete: :nothing)

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hfg_portal_dev"
  defp account_prefix(:test), do: "hfg_portal_test"
  defp account_prefix(_),     do: "hfg_portal"
end
