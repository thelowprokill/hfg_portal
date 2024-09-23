defmodule Budget.Drafts.AssumptionPopulationTotal do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.AnimalType,
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
  schema "assumption_population_totals" do
    field :is_total, :boolean, default: false
    field :month_1,  :integer, default: 0
    field :month_2,  :integer, default: 0
    field :month_3,  :integer, default: 0
    field :month_4,  :integer, default: 0
    field :month_5,  :integer, default: 0
    field :month_6,  :integer, default: 0
    field :month_7,  :integer, default: 0
    field :month_8,  :integer, default: 0
    field :month_9,  :integer, default: 0
    field :month_10, :integer, default: 0
    field :month_11, :integer, default: 0
    field :month_12, :integer, default: 0
    field :total,    :integer, default: 0

    belongs_to :draft,       Draft
    belongs_to :animal_type, AnimalType

    timestamps()
  end

  def changeset(assumption_population_total, attrs \\ %{}) do
    assumption_population_total
    |> cast(attrs, [
      :is_total,
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
      :total,
      :draft_id,
      :animal_type_id
    ])
  end
end
