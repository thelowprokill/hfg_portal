defmodule Budget.Admins.Admin do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.Users.{
    User
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "admins" do
    field :order,  :integer
    field :active, :boolean

    belongs_to :user,       User
    belongs_to :created_by, User
    belongs_to :updated_by, User

    timestamps()
  end

  def changeset(account, attrs \\ %{}) do
    account
    |> cast(attrs, [
      :order, 
      :active,
      :user_id,
      :created_by_id,
      :updated_by_id
    ])
    |> validate_required([:order, :user_id, :created_by_id, :updated_by_id])
    |> unique_constraint(:user_id, name: :admins_unique_index)
    |> unique_constraint(:order,   name: :admins_unique_index_order)
  end
end

