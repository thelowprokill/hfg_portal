defmodule Budget.Users.CompanyPermission do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.Company,
    Users.Role,
    Users.User,
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "permission_company" do
    belongs_to :role,    Role
    belongs_to :company, Company

    field :section,    :string
    field :permission, :string

    belongs_to :created_by, User
    belongs_to :updated_by, User

    timestamps()
  end

  def changeset(company, attrs \\ %{}) do
    company
    |> cast(attrs, [
      :role_id,
      :company_id,
      :section,
      :permission,
      :created_by_id,
      :updated_by_id
    ])
    |> validate_required([:role_id, :company_id, :section])
    |> unique_constraint([:role_id, :company_id, :section], name: :permission_company_unique_index)
  end
end



