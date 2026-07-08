defmodule TaskAutomationController.Users.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_task_automation_controller"
  prefix = case Application.compile_env(:task_automation_controller, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "user_roles" do
    belongs_to :user, BnwPortal.Accounts.User
    belongs_to :role, TaskAutomationController.Users.Role

    belongs_to :created_by, BnwPortal.Accounts.User
    belongs_to :updated_by, BnwPortal.Accounts.User
    field :active, :boolean, default: false

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :user_id,
      :role_id,
      :created_by_id,
      :updated_by_id,
      :active,
    ])
    |> validate_required([:user_id, :role_id])
  end
end
