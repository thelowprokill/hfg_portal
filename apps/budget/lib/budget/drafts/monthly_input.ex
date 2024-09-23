defmodule Budget.Drafts.MonthlyInput do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Drafts.Draft,
    Companies.VariableInput,
    Companies.ReportingInput
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "monthly_inputs" do
    field :month_1,              :decimal, default: 0
    field :month_2,              :decimal, default: 0
    field :month_3,              :decimal, default: 0
    field :month_4,              :decimal, default: 0
    field :month_5,              :decimal, default: 0
    field :month_6,              :decimal, default: 0
    field :month_7,              :decimal, default: 0
    field :month_8,              :decimal, default: 0
    field :month_9,              :decimal, default: 0
    field :month_10,             :decimal, default: 0
    field :month_11,             :decimal, default: 0
    field :month_12,             :decimal, default: 0
    field :variable_input_name,  :string
    field :reporting_input_name, :string

    belongs_to :draft,           Draft
    belongs_to :variable_input,  VariableInput
    belongs_to :reporting_input, ReportingInput

    timestamps()
  end

  def changeset(monthly_input, attrs \\ %{}) do
    monthly_input
    |> cast(attrs, [
      :month_1,
      :month_2,
      :month_3,
      :month_4,
      :month_5,
      :month_6,
      :month_7,
      :month_8,
      :month_9,
      :month_10,
      :month_11,
      :month_12,
      :variable_input_name,
      :reporting_input_name,
      :draft_id,
      :variable_input_id,
      :reporting_input_id
    ])
  end
end
