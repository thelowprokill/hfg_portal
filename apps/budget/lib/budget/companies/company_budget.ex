defmodule Budget.Companies.CompanyBudget do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.Company,
    Companies.Location,
    Companies.BudgetAccount
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "company_budgets" do
    field :name,            :string
    field :active,          :boolean, default: true
    field :starting_month,  :integer, default: 1
    field :target_balance,  :decimal, default: 0.0
    field :actual_balance,  :decimal, default: 0.0
    field :company_percent, :decimal, default: 0.0

    belongs_to :company,  Company
    belongs_to :location, Location

    has_many :budget_accounts, BudgetAccount

    timestamps()
  end

  def changeset(company, attrs \\ %{}) do
    company
    |> cast(attrs, [
      :name,
      :active,
      :starting_month,
      :target_balance,
      :actual_balance,
      :company_percent,
      :company_id,
      :location_id
    ])
    |> validate_required([:name])
    |> unique_constraint(:name, name: :company_budgets_name_company_id_index)
    |> check_percent()
  end

  def check_percent(changeset) do
    changeset
  end
end
