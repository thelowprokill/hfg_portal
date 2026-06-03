defmodule Budget.Repo.Migrations.CreateScheduledExpenses do
  use Ecto.Migration

  def change do
    create table(:scheduled_expenses) do
      add :bucket_id,     references(:buckets, on_delete: :delete_all), null: false
      add :amount,        :decimal, precision: 12, scale: 2, null: false
      add :description,   :string,  null: false
      add :frequency,     :string,  null: false
      add :day_of_month,  :integer
      add :day_of_week,   :integer
      add :month_of_year, :integer
      add :next_due_date, :date,    null: false
      add :active,        :boolean, null: false, default: true

      timestamps()
    end

    create index(:scheduled_expenses, [:bucket_id])
  end
end
