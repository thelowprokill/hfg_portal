defmodule Budget.Repo.Migrations.CreateDrafts do
  use Ecto.Migration

  def change do
    create table(:drafts) do
      add :name,                   :string, null: false
      add :locked,                 :boolean, default: false, null: false
      add :year,                   :integer, null: false
      add :start_date,             :date, null: false
      add :avg_dry_100,            :decimal, precision: 12, scale: 2
      add :avg_feed_markup,        :decimal, precision: 12, scale: 2
      add :as_fed_sales,           :decimal, precision: 12, scale: 2
      add :as_fed_sales_100,       :decimal, precision: 12, scale: 2
      add :as_fed_cost,            :decimal, precision: 12, scale: 2
      add :as_fed_cost_100,        :decimal, precision: 12, scale: 2
      add :annual_interest_income, :integer
      add :med_cost_per_day,       :decimal, precision: 12, scale: 4
      add :med_sales_per_day,      :decimal, precision: 12, scale: 4
      add :company_budget_id,      references(:company_budgets)
      add :draft_type_id,          references(:draft_types)
      #add :draft_phase_id,         references(:draft_phases, on_delete: :nilify_all)
      add :previous_year_draft_id, references(:drafts, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:drafts, [:company_budget_id, :year, :name], name: :drafts_unique_index)
  end
end
