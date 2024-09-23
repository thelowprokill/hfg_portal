defmodule DevTeamTimetracking.Projects.FavoriteProject do
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

  schema "favorite_projects" do
    belongs_to :user,          BnwPortal.Accounts.User
    belongs_to :project,       DevTeamTimetracking.Projects.Project
    belongs_to :fixed_project, DevTeamTimetracking.Projects.FixedProject

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :user_id,
      :project_id,
      :fixed_project_id
    ])
  end
end
