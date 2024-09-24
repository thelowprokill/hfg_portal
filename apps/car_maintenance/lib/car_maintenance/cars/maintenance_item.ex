defmodule CarMaintenance.Cars.MaintenanceItem do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hull_family_games_car_maintenance"
  prefix = case Application.compile_env(:car_maintenance, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "maintenance_items" do
    field :name,            :string
    field :interval_miles,  :integer
    field :interval_months, :integer
    field :notes,           :string
    field :active,          :boolean, default: true

    has_one :last_service_history, CarMaintenance.Cars.ServiceHistory

    belongs_to :car,        CarMaintenance.Cars.Car
    belongs_to :created_by, CarMaintenance.Users.User
    belongs_to :updated_by, CarMaintenance.Users.User

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :interval_miles,
      :interval_months,
      :notes,
      :active,
      :car_id,
      :created_by_id,
      :updated_by_id,
    ])
  end
end
