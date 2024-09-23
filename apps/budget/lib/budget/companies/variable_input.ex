defmodule Budget.Companies.VariableInput do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.Company,
    Companies.Department
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "variable_inputs" do
    field :name,   :string
    field :active, :boolean, default: true
    field :misc,   :boolean, default: false
    belongs_to :company,     Company
    has_many   :departments, Department

    timestamps()
  end

  def changeset(variable_input, attrs \\ %{}) do
    variable_input
    |> cast(attrs, [
      :name, 
      :active, 
      :misc, 
      :company_id
    ])
    |> validate_required([:name])
    |> unique_constraint(:name, name: :variable_inputs_unique_index)
    |> capitalize_name()
  end

  defp capitalize_name(changeset)  do
    name = changeset
    |> get_change(:name, get_field(changeset, :name) || "")
    |> String.split(" ")
    |> Enum.map(&String.capitalize(&1))
    |> Enum.join(" ")

    put_change(changeset, :name, name)
  end
end
