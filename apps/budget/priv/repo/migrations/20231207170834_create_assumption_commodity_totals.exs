defmodule Budget.Repo.Migrations.AssumptionCommodityTotals do
  use Ecto.Migration

  def change do
    create table(:assumption_commodity_totals) do
      add :month_1,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_2,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_3,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_4,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_5,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_6,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_7,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_8,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_9,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_10,            :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_11,            :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_12,            :decimal, precision: 12, scale: 2, null: false, default: 0
      add :total,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :draft_id,            references(:drafts, on_delete: :delete_all)
      add :variable_input_id,   references(:variable_inputs)
      add :variable_input_name, :string

      timestamps()
    end

    create index(:assumption_commodity_totals, [:draft_id, :variable_input_name, :variable_input_id], name: :assumption_commodity_totals_main_index)
  end
end
