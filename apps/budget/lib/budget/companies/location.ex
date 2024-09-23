defmodule Budget.Companies.Location do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.Company,
    Companies.CompanyBudget,
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "locations" do
    field :name,          :string
    field :yard_number,   :string
    field :external_code, :string

    belongs_to :company, Company

    has_many :budget, CompanyBudget, on_delete: :delete_all

    timestamps()
  end

  def changeset(location, attrs \\ %{}) do
    location
    |> cast(attrs, [
      :name, 
      :yard_number, 
      :external_code, 
      :company_id
    ])
    |> validate_required([:name, :external_code])
    |> unique_constraint(:name, name: :companies_unique_index)
    |> unique_constraint(:name, name: :companies_unique_index_all)
  end
end
