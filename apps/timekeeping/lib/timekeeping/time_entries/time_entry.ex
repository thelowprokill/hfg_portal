defmodule Timekeeping.TimeEntries.TimeEntry do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_timekeeping"
  prefix = case Application.compile_env(:timekeeping, :env) do
    :dev  -> prefix <> "_dev"
    :test -> prefix <> "_test"
    _     -> prefix
  end

  @schema_prefix prefix

  schema "time_entries" do
    field :job_id,     :integer
    field :start_time, :utc_datetime
    field :end_time,   :utc_datetime

    belongs_to :job, Timekeeping.Jobs.Job, define_field: false

    timestamps()
  end

  def changeset(time_entry, attrs \\ %{}) do
    time_entry
    |> cast(attrs, [
      :job_id,
      :start_time,
      :end_time,
    ])
    |> validate_required([:job_id, :start_time])
    |> validate_end_after_start()
  end

  defp validate_end_after_start(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time   = get_field(changeset, :end_time)

    cond do
      is_nil(start_time) or is_nil(end_time) -> changeset
      DateTime.compare(end_time, start_time) == :lt -> add_error(changeset, :end_time, "must be after the start time")
      true -> changeset
    end
  end
end
