defmodule Budget.Companies.AnimalSex do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Companies.Company

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "animal_sexes" do
    field :name, :string

    belongs_to :company, Company

    timestamps()
  end

  def changeset(animal_sex, attrs \\ %{}) do
    animal_sex
    |> cast(attrs, [
      :name, 
      :company_id
    ])
    |> validate_required([:name])
    |> unique_constraint(:name, name: :animal_sexes_unique_index)
  end
end
