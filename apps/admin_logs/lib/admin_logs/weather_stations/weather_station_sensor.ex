defmodule AdminLogs.WeatherStations.WeatherStationSensor do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_dashboard_sensors"
  prefix = case Application.compile_env(:sensors, :env) do
             :dev -> prefix <> "_dev"
             :test -> prefix <> "_test"
             _ -> prefix
           end

  @schema_prefix prefix

  schema "weather_station_sensors" do
    belongs_to :yard, Sensors.Yard
    field :name,        :string
    field :ip,          :string
    field :mac_address, :string

    timestamps()
  end

  def changeset(plug, attrs \\ %{}) do
    plug
    |> cast(attrs, [
          :yard_id,
          :name,
          :ip,
          :mac_address
        ])
    |> validate_required(:name)
    |> validate_required(:yard_id)
    |> validate_required(:ip)
  end
end
