defmodule Budget.Drafts.FixedPlanningLine do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Drafts.Draft,
    Companies.DepartmentAccount
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "fixed_planning_lines" do
    field :amount,  :decimal, default: 0
    field :comment, :string

    belongs_to :draft,              Draft
    belongs_to :department_account, DepartmentAccount

    timestamps()
  end

  def changeset(fixed_planning_lines, attrs \\ %{}) do
    fixed_planning_lines
    |> cast(attrs, [
      :amount, 
      :comment, 
      :draft_id, 
      :department_account_id
    ])
  end
end
