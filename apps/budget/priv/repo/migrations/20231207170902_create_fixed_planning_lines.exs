defmodule Budget.Repo.Migrations.CreateFixedPlanningLines do
  use Ecto.Migration

  def change do
    create table(:fixed_planning_lines) do
      add :amount,                :decimal, precision: 12, scale: 2, null: false, default: 0
      add :comment,               :text
      add :draft_id,              references(:drafts, on_delete: :delete_all)
      add :department_account_id, references(:departments_accounts, on_delete: :delete_all)

      timestamps()
    end

    create index(:fixed_planning_lines, [:draft_id, :department_account_id], name: :fixed_planning_lines_main_index)
  end
end
