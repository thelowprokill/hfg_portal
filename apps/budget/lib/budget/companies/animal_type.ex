defmodule Budget.Companies.AnimalType do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Drafts.AssumptionPopulationTotal,
    Companies.Company
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "animal_types" do
    field :name, :string

    belongs_to :company, Company

    has_many :assumption_population_totals, AssumptionPopulationTotal, on_delete: :delete_all

    timestamps()
  end

  def changeset(animal_type, attrs \\ %{}) do
    animal_type
    |> cast(attrs, [
      :name, 
      :company_id
    ])
    |> validate_required([:name])
    |> unique_constraint(:name, name: :animal_types_unique_index)
  end
end
