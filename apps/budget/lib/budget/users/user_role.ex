defmodule Budget.Users.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
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

  schema "user_roles" do
    belongs_to :role,       Role
    belongs_to :user,       User
    belongs_to :created_by, User
    belongs_to :updated_by, User

    timestamps()
  end

  def changeset(user_role, attrs \\ %{}) do
    user_role
    |> cast(attrs, [
      :role_id,
      :user_id,
      :created_by_id,
      :updated_by_id,
    ])
    |> validate_required([:role_id, :user_id, :created_by_id, :updated_by_id])
  end
end
