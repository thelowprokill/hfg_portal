defmodule Budget.Drafts.VariablePlanningLine do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Drafts.Draft,
    Companies.DepartmentAccount,
    Companies.VariableInput
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "variable_planning_lines" do
    field :amount,              :decimal, default: 0
    field :total,               :decimal, default: 0
    field :comment,             :string
    field :variable_input_name, :string
    belongs_to :draft,              Draft
    belongs_to :department_account, DepartmentAccount
    belongs_to :variable_input,     VariableInput

    timestamps()
  end

  def changeset(variable_planning_lines, attrs \\ %{}) do
    variable_planning_lines
    |> cast(attrs, [
      :amount, 
      :total, 
      :comment, 
      :variable_input_name, 
      :draft_id, 
      :department_account_id, 
      :variable_input_id
    ])
  end
end
