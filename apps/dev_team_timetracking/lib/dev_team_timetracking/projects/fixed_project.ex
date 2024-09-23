defmodule DevTeamTimetracking.Projects.FixedProject do
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

  schema "fixed_projects" do
    field :name,            :string
    field :description,     :string
    field :key,             :string
    field :status,          :string
    field :project_percent, :integer
    
    belongs_to :created_by, BnwPortal.Accounts.User
    has_many :timesheets, DevTeamTimetracking.Timesheets.Timesheet, foreign_key: :project_id

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :description,
      :key,
      :status,
      :project_percent,
      :created_by_id,
    ])
  end
end
