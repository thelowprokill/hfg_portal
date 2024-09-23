defmodule DevTeamTimetracking.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_dashboard_plugs_app"
  #prefix = case Application.compile_env(:dev_team_timetracking, :env) do
  #  :dev   -> prefix <> "_dev"
  #  :test  -> prefix <> "_test"
  #  :trial -> prefix <> "_trial"
  #  _      -> prefix
  #end

  @schema_prefix prefix

  schema "zoho_projects" do
    field :name,            :string
    field :description,     :string
    field :key,             :string
    field :status,          :string
    field :project_percent, :integer
    
    has_many :timesheets, DevTeamTimetracking.Timesheets.Timesheet, foreign_key: :project_id

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
    ])
  end
end
