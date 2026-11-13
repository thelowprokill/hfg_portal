defmodule TaskAutomationController.Jobs.Priority do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias TaskAutomationController.Repo

  prefix = "task_automation_controller"
  prefix = case Application.compile_env(:task_automation_controller, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "priorities" do
    field :name,        :string
    field :order,       :integer

    belongs_to :created_by, TaskAutomationController.Users.User
    belongs_to :updated_by, TaskAutomationController.Users.User
    field :active, :boolean, default: true

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :order,
      :created_by_id,
      :updated_by_id,
      :active,
    ])
    |> set_order()
    |> validate_required([:name])
  end

  defp set_order(changeset) do
    case get_field(changeset, :order) do
      nil ->
        max =
          TaskAutomationController.Jobs.Priority
          |> order_by(desc: :order)
          |> limit(1)
          |> Repo.one()
          |> case do
            nil -> 0
            item -> item.order
          end
        put_change(changeset, :order, max + 1)
      _   -> changeset
    end
  end
end
