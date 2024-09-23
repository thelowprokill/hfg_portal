defmodule AdminLogs.WeatherStations.WeatherStationData do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_dashboard_sensors"
  prefix = case Application.compile_env(:sensors, :env) do
             :dev -> prefix <> "_dev"
             :test -> prefix <> "_test"
             _ -> prefix
           end

  @schema_prefix prefix

  schema "weather_station_rtd" do
    belongs_to :sensor, Sensors.WeatherStationSensor
    field :collection_date, :date
    field :collection_time, :time
    field :tempout,         :decimal
    field :humout,          :decimal
    field :tempin,          :decimal
    field :humin,           :integer
    field :windspd,         :decimal
    field :windddir,        :decimal
    field :windavg2,        :decimal
    field :windavg10,       :decimal
    field :gust,            :decimal
    field :gust_dir,        :integer
    field :bar,             :decimal
    field :altime,          :decimal
    field :rawbar,          :decimal
    field :bartr,           :integer
    field :dew,             :decimal
    field :cdew,            :decimal
    field :chill,           :decimal
    field :heat,            :decimal
    field :thsw,            :decimal
    field :uv,              :decimal
    field :solar,           :integer
    field :rainr,           :decimal
    field :storm,           :decimal
    field :rain15,          :decimal
    field :rain1h,          :decimal
    field :raind,           :decimal
    field :raindly,         :decimal
    field :rain24,          :decimal
    field :rainmon,         :decimal
    field :rainyear,        :decimal
    field :etday,           :decimal
    field :etmon,           :decimal
    field :etyear,          :decimal
    field :bat,             :decimal
    field :trbat,           :integer
    field :foreico,         :integer
    field :forrule,         :integer
    field :sunrt,           :string
    field :sunst,           :string
    field :success,           :boolean

    timestamps()
  end

  def changeset(plug, attrs \\ %{}) do
    plug
    |> cast(attrs, [
          :sensor_id,
          :collection_date,
          :collection_time,
          :tempout,
          :humout,
          :tempin,
          :humin,
          :windspd,
          :windddir,
          :windavg2,
          :windavg10,
          :gust,
          :gust_dir,
          :bar,
          :altime,
          :rawbar,
          :bartr,
          :dew,
          :cdew,
          :chill,
          :heat,
          :thsw,
          :uv,
          :solar,
          :rainr,
          :storm,
          :rain15,
          :rain1h,
          :raind,
          :raindly,
          :rain24,
          :rainmon,
          :rainyear,
          :etday,
          :etmon,
          :etyear,
          :bat,
          :trbat,
          :foreico,
          :forrule,
          :sunrt,
          :sunst,
          :success
        ])
  end
end
