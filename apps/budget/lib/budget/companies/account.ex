defmodule Budget.Companies.Account do
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

  schema "accounts" do
    field :name,           :string
    field :account_number, :string
    field :external_id,    :integer
    field :type,           :string
    field :active,         :boolean, default: true

    belongs_to :company, Company

    many_to_many :departments, Department, join_through: "departments_accounts", on_replace: :delete

    timestamps()
  end

  def changeset(account, attrs \\ %{}) do
    account
    |> cast(attrs, [
      :name, 
      :account_number, 
      :external_id,
      :type,
      :active, 
      :company_id
    ])
    |> validate_required([:name, :account_number])
    |> unique_constraint(:name, name: :accounts_unique_index)
    |> unique_constraint(:name, name: :accounts_unique_name_index)
    |> unique_constraint(:account_number, name: :accounts_unique_number_index)
  end
end
