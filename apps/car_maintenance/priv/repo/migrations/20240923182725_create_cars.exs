defmodule CarMaintenance.Repo.Migrations.CreateCars do
  use Ecto.Migration

  def change do
    create table(:cars) do
      add :name,          :string
      add :year,          :integer
      add :make,          :string
      add :model,         :string
      add :vin,           :string
      add :license_plate, :string
      add :active,        :boolean, default: true
      add :created_by_id, references(:users, prefix: account_prefix(Application.get_env(:car_maintenance, :env)), on_delete: :nothing)
      add :updated_by_id, references(:users, prefix: account_prefix(Application.get_env(:car_maintenance, :env)), on_delete: :nothing)

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hfg_portal_dev"
  defp account_prefix(:test), do: "hfg_portal_test"
  defp account_prefix(_),     do: "hfg_portal"
end
