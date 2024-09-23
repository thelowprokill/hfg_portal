defmodule Budget.Users.Role do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.Company,
    Users.User,
    Users.UserRole,
    Users.HomePermission,
    Users.CompanyPermission,
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "roles" do
    field :name,   :string
    field :active, :boolean

    belongs_to :company, Company

    belongs_to :created_by, User
    belongs_to :updated_by, User

    has_many :user_roles,          UserRole
    has_many :company_permissions, CompanyPermission
    has_many :home_permissions,    HomePermission

    timestamps()
  end

  def changeset(company, attrs \\ %{}) do
    company
    |> cast(attrs, [
      :name, 
      :active,
      :company_id,
      :created_by_id,
      :updated_by_id
    ])
    |> validate_required([:name, :company_id])
    |> unique_constraint([:name, :company_id], name: :roles_unique_index)
  end
end

