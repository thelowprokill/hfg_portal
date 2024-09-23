defmodule Budget.Companies.Company do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.Account,
    Companies.Department,
    Companies.DraftType,
    Companies.CompanyBudget,
    Companies.Location,
    Companies.ReportingInput,
    Companies.VariableInput,
    Users.Role,
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "companies" do
    field :name,           :string
    field :target_balance, :decimal, default: 0.0
    field :actual_balance, :decimal, default: 0.0
    field :active,         :boolean, default: true

    has_many :accounts,         Account,        on_delete: :delete_all
    has_many :departments,      Department,     on_delete: :delete_all
    has_many :locations,        Location,       on_delete: :delete_all
    has_many :company_budgets,  CompanyBudget,  on_delete: :delete_all
    has_many :reporting_inputs, ReportingInput, on_delete: :delete_all
    has_many :variable_inputs,  VariableInput,  on_delete: :delete_all
    has_many :roles,            Role,           on_delete: :delete_all
    has_many :draft_types,      DraftType,      on_delete: :delete_all

    timestamps()
  end

  def changeset(company, attrs \\ %{}) do
    company
    |> cast(attrs, [
      :name, 
      :target_balance, 
      :actual_balance, 
      :active
    ])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
