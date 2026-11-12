defmodule TaskAutomationController.Users.Role do
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

  schema "roles" do
    field :name, :string
    field :description, :string
    field :admin, :boolean, default: false 

    belongs_to :created_by, TaskAutomationController.Users.User
    belongs_to :updated_by, TaskAutomationController.Users.User
    field :active, :boolean, default: true

    #has_many :user_roles, TaskAutomationController.UserRoles
    #has_many :roles_jobs, TaskAutomationController.RolesJobs
    #has_many :jobs, through: [:roles_jobs, :job]

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :description,
      :created_by_id,
      :updated_by_id,
      :active,
    ])
    #|> validate_required([:name])
  end
end
