defmodule Timekeeping.Repo.Migrations.CreateTimeEntries do
  use Ecto.Migration

  def change do
    create table(:time_entries) do
      add :job_id,     references(:jobs, on_delete: :delete_all), null: false
      add :start_time, :utc_datetime, null: false
      add :end_time,   :utc_datetime

      timestamps()
    end

    create index(:time_entries, [:job_id])
    create index(:time_entries, [:job_id, :end_time])
  end
end
