defmodule Budget.Repo.Migrations.CreateBudgetReportingInputs do
  use Ecto.Migration

  def change do
    create table(:budgets_reporting_inputs) do
      add :company_budget_id,  references(:company_budgets, on_delete: :delete_all)
      add :reporting_input_id, references(:reporting_inputs, on_delete: :delete_all)
    end

    create unique_index(:budgets_reporting_inputs, [:company_budget_id, :reporting_input_id], name: :budgets_reporting_inputs_unique_index)
    create index(:budgets_reporting_inputs, :company_budget_id)
    create index(:budgets_reporting_inputs, :reporting_input_id)
  end
end
