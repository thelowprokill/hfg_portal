defmodule TaskAutomationController.Jobs.Job do
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

  schema "jobs" do
    field :name,          :string
    field :description,   :string
    belongs_to :priority, TaskAutomationController.Jobs.Priority
    field :address,       :string
    field :asynchronous,  :boolean, default: false
    field :avg_runtime,   :integer

    belongs_to :created_by, TaskAutomationController.Users.User
    belongs_to :updated_by, TaskAutomationController.Users.User
    field :active, :boolean, default: true

    has_many :queue, TaskAutomationController.Jobs.Queue
    has_many :schedules, TaskAutomationController.Jobs.Schedule

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :description,
      :priority_id,
      :address,
      :asynchronous,
      :avg_runtime,
      :created_by_id,
      :updated_by_id,
      :active,
    ])
    |> validate_required([:name, :address, :priority_id])
  end
end
