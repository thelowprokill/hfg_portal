defmodule Timekeeping.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :user_id,     :integer, null: false
      add :name,        :string,  null: false
      add :client,      :string
      add :hourly_rate, :decimal, precision: 12, scale: 2
      add :active,      :boolean, null: false, default: true

      timestamps()
    end

    create index(:jobs, [:user_id])
  end
end
