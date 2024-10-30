defmodule WifeTime.Users.User do
  use Ecto.Schema

  prefix = "hfg_portal"
  prefix = case Application.compile_env(:wife_time, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "users" do
    field :username,     :string
    field :email,        :string
    field :first_name,   :string
    field :last_name,    :string
    field :role,         :map, virtual: true
    field :portal_admin, :boolean
    field :dev_admin,    :boolean
    field :admin_mode,   :boolean, default: false, virtual: true

    has_one :user_role, WifeTime.Users.UserRole

    timestamps()
  end
end
