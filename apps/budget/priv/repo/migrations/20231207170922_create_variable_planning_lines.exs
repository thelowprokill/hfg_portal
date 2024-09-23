defmodule Budget.Repo.Migrations.CreateVariablePlanningLines do
  use Ecto.Migration

  def change do
    create table(:variable_planning_lines) do
      add :amount,                :decimal, precision: 12, scale: 4, null: false, default: 0
      add :total,                 :decimal, precision: 12, scale: 2, null: false, default: 0
      add :comment,               :text
      add :draft_id,              references(:drafts, on_delete: :delete_all)
      add :department_account_id, references(:departments_accounts, on_delete: :delete_all)
      add :variable_input_id,     references(:variable_inputs, on_delete: :delete_all)
      add :variable_input_name,   :string

      timestamps()
    end

    create index(:variable_planning_lines, [:draft_id, :department_account_id, :variable_input_name], name: :variable_planning_lines_main_index)
  end
end
