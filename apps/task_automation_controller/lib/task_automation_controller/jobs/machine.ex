defmodule TaskAutomationController.Jobs.Machine do
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

  schema "machines" do
    field :name,        :string
    field :description, :string
    field :address,     :string


    belongs_to :created_by, TaskAutomationController.Users.User
    belongs_to :updated_by, TaskAutomationController.Users.User
    field :active, :boolean, default: true

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :description,
      :address,
      :created_by_id,
      :updated_by_id,
      :active,
    ])
    |> validate_required([:name, :address])
  end
end
