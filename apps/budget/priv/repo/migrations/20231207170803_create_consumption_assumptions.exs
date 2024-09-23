defmodule Budget.Repo.Migrations.CreateConsumptionAssumptions do
  use Ecto.Migration

  def change do
    create table(:consumption_assumptions) do
      add :in_weight,      :integer, null: false, default: 0
      add :out_weight,     :integer, null: false, default: 0
      add :population_pct, :integer, null: false, default: 0
      add :month_1,        :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_2,        :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_3,        :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_4,        :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_5,        :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_6,        :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_7,        :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_8,        :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_9,        :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_10,       :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_11,       :decimal, null: false, precision: 12, scale: 2, default: 0
      add :month_12,       :decimal, null: false, precision: 12, scale: 2, default: 0
      add :total,          :decimal, null: false, precision: 12, scale: 2, default: 0
      add :draft_id,       references(:drafts, on_delete: :delete_all)
      add :animal_sex_id,  references(:animal_sexes)
      add :animal_type_id, references(:animal_types)

      timestamps()
    end

    create unique_index(:consumption_assumptions, [:draft_id, :animal_sex_id, :animal_type_id], name: :consumption_assumptions_unique_index)
  end
end
