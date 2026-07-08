defmodule TaskAutomationController.Users.User do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal"
  prefix = case Application.compile_env(:task_automation_controller, :env) do
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
    field :active,       :boolean

    has_many :user_roles, TestDashboard.Users.UserRole, foreign_key: :user_id

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
    ])
  end
end
