defmodule TaskAutomationController.Users.RoleJob do
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

  schema "roles_jobs" do
    belongs_to :role, TaskAutomationController.Users.Role
    belongs_to :job,  TaskAutomationController.Jobs.Job

    belongs_to :created_by, TaskAutomationController.Users.User
    belongs_to :updated_by, TaskAutomationController.Users.User
    field :active, :boolean, default: true

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :role_id,
      :job_id,
      :created_by_id,
      :updated_by_id,
      :active,
    ])
  end
end
