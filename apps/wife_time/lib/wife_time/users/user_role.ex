defmodule WifeTime.Users.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_wife_time"
  prefix = case Application.compile_env(:wife_time, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "user_roles" do
    belongs_to :user, WifeTime.Users.User
    field :role,      :string

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
