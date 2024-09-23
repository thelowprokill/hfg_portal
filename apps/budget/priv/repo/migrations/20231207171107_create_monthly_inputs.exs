defmodule Budget.Repo.Migrations.CreateMonthlyInputs do
  use Ecto.Migration

  def change do
    create table(:monthly_inputs) do
      add :month_1,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_2,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_3,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_4,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_5,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_6,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_7,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_8,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_9,              :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_10,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_11,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :month_12,             :decimal, precision: 12, scale: 2, null: false, default: 0
      add :draft_id,             references(:drafts, on_delete: :delete_all)
      add :variable_input_id,    references(:variable_inputs, on_delete: :delete_all)
      add :variable_input_name,  :string
      add :reporting_input_id,   references(:reporting_inputs, on_delete: :delete_all)
      add :reporting_input_name, :string

      timestamps()
    end

    create index(:monthly_inputs, [:draft_id, :variable_input_name, :variable_input_id], name: :monthly_inputs_main_index)
  end
end
