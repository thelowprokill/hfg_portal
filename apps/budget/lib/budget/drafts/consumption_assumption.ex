defmodule Budget.Drafts.ConsumptionAssumption do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.AnimalSex,
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
  schema "consumption_assumptions" do
    field :index,          :integer, virtual: true
    field :in_weight,      :integer
    field :out_weight,     :integer
    field :population_pct, :integer
    field :month_1,        :decimal, default: 0
    field :month_2,        :decimal, default: 0
    field :month_3,        :decimal, default: 0
    field :month_4,        :decimal, default: 0
    field :month_5,        :decimal, default: 0
    field :month_6,        :decimal, default: 0
    field :month_7,        :decimal, default: 0
    field :month_8,        :decimal, default: 0
    field :month_9,        :decimal, default: 0
    field :month_10,       :decimal, default: 0
    field :month_11,       :decimal, default: 0
    field :month_12,       :decimal, default: 0
    field :total,          :decimal, default: 0

    belongs_to :animal_sex,  AnimalSex
    belongs_to :animal_type, AnimalType
    belongs_to :draft,       Draft

    timestamps()
  end

  def changeset(location, attrs \\ %{}) do
    location
    |> cast(attrs, [
      :index,
      :in_weight,
      :out_weight,
      :population_pct,
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
      :animal_sex_id,
      :animal_type_id,
      :draft_id,
      :total
    ])
    |> unique_constraint(:in_weight, name: :consumption_assumptions_unique_index)
    |> calculate_total()
  end

  defp calculate_total(changeset) do
    month_1  = get_field(changeset, :month_1,  Decimal.new(0))
    month_2  = get_field(changeset, :month_2,  Decimal.new(0))
    month_3  = get_field(changeset, :month_3,  Decimal.new(0))
    month_4  = get_field(changeset, :month_4,  Decimal.new(0))
    month_5  = get_field(changeset, :month_5,  Decimal.new(0))
    month_6  = get_field(changeset, :month_6,  Decimal.new(0))
    month_7  = get_field(changeset, :month_7,  Decimal.new(0))
    month_8  = get_field(changeset, :month_8,  Decimal.new(0))
    month_9  = get_field(changeset, :month_9,  Decimal.new(0))
    month_10 = get_field(changeset, :month_10, Decimal.new(0))
    month_11 = get_field(changeset, :month_11, Decimal.new(0))
    month_12 = get_field(changeset, :month_12, Decimal.new(0))

    put_change(changeset, :total,
      Decimal.new(0)
      |> Decimal.add(month_1 )
      |> Decimal.add(month_2 )
      |> Decimal.add(month_3 )
      |> Decimal.add(month_4 )
      |> Decimal.add(month_5 )
      |> Decimal.add(month_6 )
      |> Decimal.add(month_7 )
      |> Decimal.add(month_8 )
      |> Decimal.add(month_9 )
      |> Decimal.add(month_10)
      |> Decimal.add(month_11)
      |> Decimal.add(month_12)
    )
  end
end
