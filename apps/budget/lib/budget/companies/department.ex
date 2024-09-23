defmodule Budget.Companies.Department do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.Account,
    Companies.Company,
    Companies.DepartmentAccount,
    Companies.VariableInput,
    CompanyPermVariableInputs
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "departments" do
    field :name,                   :string
    field :department_number,      :string
    field :external_code,          :string
    field :active,                 :boolean, default: true
    field :variable_input_name,    :string
    field :exclude_from_yardage,   :boolean, default: false
    field :variable_input_id_in,   :integer, virtual: true

    belongs_to :company,        Company
    belongs_to :variable_input, VariableInput

    many_to_many :accounts, Account, join_through: "departments_accounts", on_replace: :delete

    has_many :department_accounts, DepartmentAccount

    timestamps()
  end

  def changeset(department, attrs \\ %{}) do
    department
    |> cast(attrs, [
      :name,
      :department_number,
      :external_code,
      :active,
      :company_id,
      :variable_input_id,
      :variable_input_id_in,
      :variable_input_name,
      :exclude_from_yardage
    ])
    |> cast_assoc(:accounts, with: &Account.changeset/2)
    |> validate_required([:name, :department_number])
    |> unique_constraint(:name, name: :departments_unique_index)
    |> unique_constraint(:name, name: :departments_unique_name_index)
    |> unique_constraint(:name, name: :departments_unique_number_index)
    |> set_up_var_input_id
    |> fix_var_input_id
  end

  defp fix_var_input_id(changeset) do
    changeset
    |> get_field(:variable_input_id_in)
    |> case do
      val when is_nil(val) or val in [-1, -2] -> nil
      val                                     -> val
    end
    |> fn x -> put_change(changeset, :variable_input_id, x) end.()
  end

  def set_up_var_input_id(changeset) do
    id    = get_field(changeset, :variable_input_id)
    id_in = get_field(changeset, :variable_input_id_in)
    name  = get_field(changeset, :variable_input_name)

    cond do
      is_nil(id_in) && id                 -> put_change(changeset, :variable_input_id_in, id)
      is_nil(id_in) && is_nil(id) && name -> put_change(changeset, :variable_input_id_in, Enum.find(CompanyPermVariableInputs.list(), &(&1.name == name)).id)
      true                                -> changeset
    end
  end
end
