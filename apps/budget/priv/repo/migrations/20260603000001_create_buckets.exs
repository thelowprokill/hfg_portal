defmodule Budget.Repo.Migrations.CreateBuckets do
  use Ecto.Migration

  def change do
    execute("CREATE SCHEMA IF NOT EXISTS \"#{Application.get_env(:budget, Budget.Repo)[:migration_default_prefix]}\"", "")

    create table(:buckets) do
      add :user_id,              :integer, null: false
      add :name,                 :string,  null: false
      add :description,          :text
      add :balance,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :monthly_budget,       :decimal, precision: 12, scale: 2
      add :monthly_contribution, :decimal, precision: 12, scale: 2
      add :max_balance,          :decimal, precision: 12, scale: 2

      timestamps()
    end

    create index(:buckets, [:user_id])
  end
end
