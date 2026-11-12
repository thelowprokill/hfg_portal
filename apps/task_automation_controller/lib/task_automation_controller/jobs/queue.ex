defmodule TaskAutomationController.Jobs.Queue do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "task_automation_controller"
  prefix = case Application.compile_env(:task_automation_controller, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "queue" do
    belongs_to :job, TaskAutomationController.Jobs.Job
    belongs_to :machine, TaskAutomationController.Jobs.Machine

    field :status,       :string
    field :started_at,   :naive_datetime
    field :completed_at, :naive_datetime
    field :runtime,      :integer
    field :type,         :string

    belongs_to :user, TaskAutomationController.Users.User

    belongs_to :created_by, TaskAutomationController.Users.User
    belongs_to :updated_by, TaskAutomationController.Users.User
    field :active, :boolean, default: true

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :job_id,
      :machine_id,
      :status,
      :started_at,
      :completed_at,
      :runtime,
      :type,
      :user_id,
      :created_by_id,
      :updated_by_id,
      :active,
    ])
    |> validate_required([:job_id, :status, :type])
  end
end
