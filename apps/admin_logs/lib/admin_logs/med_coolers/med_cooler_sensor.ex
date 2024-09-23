defmodule AdminLogs.MedCoolers.MedCoolerSensor do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_dashboard_sensors"
  prefix = case Application.compile_env(:sensors, :env) do
             :dev -> prefix <> "_dev"
             :test -> prefix <> "_test"
             _ -> prefix
           end

  @schema_prefix prefix

  schema "med_cooler_sensors" do
    belongs_to :yard, Sensors.Yard
    field :name,         :string
    field :ip,           :string
    field :min_alarm,    :integer
    field :max_alarm,    :integer
    field :status_alarm, :boolean

    timestamps()
  end

  def changeset(plug, attrs \\ %{}) do
    plug
    |> cast(attrs, [
      :yard_id,
      :name,
      :ip,
      :min_alarm,
      :max_alarm,
      :status_alarm
    ])
    |> validate_required(:name)
    |> validate_required(:yard_id)
    |> validate_required(:ip)
    |> validate_alarm()
  end

  def validate_alarm(changeset) do
    {_, min} = fetch_field(changeset, :min_alarm)
    {_, max} = fetch_field(changeset, :max_alarm)

    cond do
      min && max && min >= max ->
        changeset
        |> put_change(:max_alarm, min + 1)
      true ->
        changeset
    end
  end
end
