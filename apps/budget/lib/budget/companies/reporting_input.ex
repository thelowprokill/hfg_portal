defmodule Budget.Companies.ReportingInput do
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

  schema "reporting_inputs" do
    field :name,   :string
    field :active, :boolean, default: true

    belongs_to :company, Company

    timestamps()
  end

  def changeset(reporting_input, attrs \\ %{}) do
    reporting_input
    |> cast(attrs, [
      :name, 
      :active, 
      :company_id
    ])
    |> validate_required([:name])
    |> unique_constraint(:name, name: :reporting_inputs_unique_index)
  end
end
