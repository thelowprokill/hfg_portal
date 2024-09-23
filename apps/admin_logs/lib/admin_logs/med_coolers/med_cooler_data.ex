defmodule AdminLogs.MedCoolers.MedCoolerData do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_dashboard_sensors"
  prefix = case Application.compile_env(:sensors, :env) do
             :dev -> prefix <> "_dev"
             :test -> prefix <> "_test"
             _ -> prefix
           end

  @schema_prefix prefix

  schema "med_cooler_data" do
    belongs_to :sensor, Sensors.MedCoolerSensor

    field :collection_date, :date
    field :collection_time, :time
    field :temperature,     :decimal
    field :door,            :boolean
    field :status_ok,       :boolean
    field :status_power,    :boolean
    field :status_id,       :integer

    timestamps()
  end

  def changeset(plug, attrs \\ %{}) do
    plug
    |> cast(attrs, [
      :sensor_id,
      :collection_date,
      :collection_time,
      :temperature,
      :door,
      :status_ok,
      :status_power,
      :status_id,
    ])
  end
end
