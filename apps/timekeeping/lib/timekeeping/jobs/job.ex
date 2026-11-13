defmodule Timekeeping.Jobs.Job do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "timekeeping"
  prefix = case Application.compile_env(:timekeeping, :env) do
    :dev  -> prefix <> "_dev"
    :test -> prefix <> "_test"
    _     -> prefix
  end

  @schema_prefix prefix

  schema "jobs" do
    field :user_id,     :integer
    field :name,        :string
    field :client,      :string
    field :hourly_rate, :decimal
    field :active,      :boolean, default: true

    has_many :time_entries, Timekeeping.TimeEntries.TimeEntry

    timestamps()
  end

  def changeset(job, attrs \\ %{}) do
    job
    |> cast(attrs, [
      :user_id,
      :name,
      :client,
      :hourly_rate,
      :active,
    ])
    |> validate_required([:user_id, :name])
  end
end
