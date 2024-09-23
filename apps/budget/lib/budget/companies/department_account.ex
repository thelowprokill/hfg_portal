defmodule Budget.Companies.DepartmentAccount do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.Account,
    Companies.Department
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "departments_accounts" do
    belongs_to :account,    Account
    belongs_to :department, Department

    timestamps()
  end

  def changeset(department_account, attrs \\ %{}) do
    department_account
    |> cast(attrs, [
      :account_id, 
      :department_id
    ])
  end
end
