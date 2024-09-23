defmodule AdminLogs.Users.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_portal_admin_logs"
  prefix = case Application.compile_env(:admin_logs, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "user_roles" do
    belongs_to :user,   BnwPortal.Accounts.User
    field :role, :string

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :user_id,
      :role,
    ])
    |> validate_required([:user_id, :role])
  end
end
