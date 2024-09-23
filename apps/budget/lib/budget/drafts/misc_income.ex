defmodule Budget.Drafts.MiscIncome do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.VariableInput,
    Drafts.Draft
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  # month_1 is first month of budget not necessarily January
  schema "misc_incomes" do
    field :index,    :integer, virtual: true
    field :month_1,  :decimal, default: 0
    field :month_2,  :decimal, default: 0
    field :month_3,  :decimal, default: 0
    field :month_4,  :decimal, default: 0
    field :month_5,  :decimal, default: 0
    field :month_6,  :decimal, default: 0
    field :month_7,  :decimal, default: 0
    field :month_8,  :decimal, default: 0
    field :month_9,  :decimal, default: 0
    field :month_10, :decimal, default: 0
    field :month_11, :decimal, default: 0
    field :month_12, :decimal, default: 0

    belongs_to :draft,          Draft
    belongs_to :variable_input, VariableInput

    timestamps()
  end

  def changeset(misc_income, attrs \\ %{}) do
    misc_income
    |> cast(attrs, [
      :index,
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
      :draft_id,
      :variable_input_id,
    ])
  end
end
