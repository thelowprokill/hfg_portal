defmodule Budget.Users.User do
  use Ecto.Schema

  prefix = case Mix.env do
    :dev   -> "bnw_portal_dev"
    :test  -> "bnw_portal_test"
    :trial -> "bnw_portal_trial"
    _      -> "bnw_portal"
  end
  @schema_prefix prefix

  schema "users" do
    field :username,     :string
    field :email,        :string
    field :first_name,   :string
    field :last_name,    :string
    field :active,       :boolean
    field :portal_admin, :boolean
    field :dev_admin,    :boolean
  end

  def changeset(user, _attrs \\ %{}), do: user
end
