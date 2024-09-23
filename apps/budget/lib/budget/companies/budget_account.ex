defmodule Budget.Companies.BudgetAccount do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.CompanyBudget,
    Companies.DepartmentAccount
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "budgets_accounts" do
    belongs_to :company_budget,     CompanyBudget
    belongs_to :department_account, DepartmentAccount

    timestamps()
  end

  def changeset(department_account, attrs \\ %{}) do
    department_account
    |> cast(attrs, [
      :company_budget_id, 
      :department_account_id
    ])
  end
end

