defmodule CarMaintenance.Cars.Car do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "car_maintenance"
  prefix = case Application.compile_env(:car_maintenance, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "cars" do
    field :name,          :string
    field :year,          :integer
    field :make,          :string
    field :model,         :string
    field :vin,           :string
    field :license_plate, :string
    field :active,        :boolean, default: true

    has_one :service_history, CarMaintenance.Cars.ServiceHistory, foreign_key: :car_id

    belongs_to :created_by, CarMaintenance.Users.User
    belongs_to :updated_by, CarMaintenance.Users.User

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,          
      :year,          
      :make,          
      :model,         
      :vin,           
      :license_plate, 
      :active,        
      :created_by_id,
      :updated_by_id,
    ])
  end
end
