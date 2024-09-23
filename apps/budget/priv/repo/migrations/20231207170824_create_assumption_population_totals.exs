defmodule Budget.Repo.Migrations.AssumptionPopulationTotals do
  use Ecto.Migration

  def change do
    create table(:assumption_population_totals) do
      add :is_total,       :boolean, null: false, default: false
      add :month_1,        :integer, null: false, default: 0
      add :month_2,        :integer, null: false, default: 0
      add :month_3,        :integer, null: false, default: 0
      add :month_4,        :integer, null: false, default: 0
      add :month_5,        :integer, null: false, default: 0
      add :month_6,        :integer, null: false, default: 0
      add :month_7,        :integer, null: false, default: 0
      add :month_8,        :integer, null: false, default: 0
      add :month_9,        :integer, null: false, default: 0
      add :month_10,       :integer, null: false, default: 0
      add :month_11,       :integer, null: false, default: 0
      add :month_12,       :integer, null: false, default: 0
      add :total,          :integer, null: false, default: 0
      add :draft_id,       references(:drafts, on_delete: :delete_all)
      add :animal_type_id, references(:animal_types)

      timestamps()
    end

    create index(:assumption_population_totals, [:draft_id, :animal_type_id])
  end
end
