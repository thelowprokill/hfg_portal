defmodule DevTeamTimetracking.Capacities.Capacity do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_portal_dev_team_timetracking"
  prefix = case Application.compile_env(:dev_team_timetracking, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "capacities" do
    belongs_to :user, DevTeamTimetracking.Accounts.User
    field :monday,    :date
    field :capacity,  :integer

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :user_id,
      :monday,
      :capacity,
    ])
  end
end
