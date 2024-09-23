defmodule Budget.Repo.Migrations.CreateExtraPlanningLines do
  use Ecto.Migration

  def change do
    create table(:extra_planning_lines) do
      add :month_1,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_2,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_3,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_4,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_5,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_6,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_7,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_8,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_9,               :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_10,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_11,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_12,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :total,                 :decimal, precision: 12, scale: 2, null: false, default: 0
      add :comment,               :text
      add :draft_id,              references(:drafts, on_delete: :delete_all)
      add :department_account_id, references(:departments_accounts, on_delete: :delete_all)

      timestamps()
    end

    create index(:extra_planning_lines, [:draft_id, :department_account_id], name: :extra_planning_lines_main_index)
  end
end
