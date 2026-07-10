defmodule CarMaintenance.Cars.ServiceHistory do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_car_maintenance"
  prefix = case Application.compile_env(:car_maintenance, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "service_history" do
    field :service_date, :date
    field :mileage,      :integer
    field :name,         :string
    field :named_item,   :boolean, default: false
    field :notes,        :string

    belongs_to :car,              CarMaintenance.Cars.Car
    belongs_to :maintenance_item, CarMaintenance.Cars.MaintenanceItem

    belongs_to :created_by,       CarMaintenance.Users.User
    belongs_to :updated_by,       CarMaintenance.Users.User

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :service_date,
      :mileage,
      :name,
      :named_item,
      :notes,
      :car_id,
      :maintenance_item_id,
      :created_by_id,
      :updated_by_id,
    ])
  end
end
