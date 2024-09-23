defmodule DevTeamTimetracking.Timesheets.Timesheet do
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

  schema "timesheets" do
    field :entry_date, :date
    field :start,      :time
    field :end,        :time
    field :hours,      :integer
    field :minutes,    :integer
    field :task_key,   :string
    field :comments,   :string

    belongs_to :user,          BnwPortal.Accounts.User
    belongs_to :project,       DevTeamTimetracking.Projects.Project
    belongs_to :fixed_project, DevTeamTimetracking.Projects.FixedProject

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :entry_date,
      :start,
      :end,
      :hours,
      :minutes,
      :task_key,
      :comments,
      :user_id,
      :project_id,
      :fixed_project_id,
    ])
    |> validate_required([:user_id])
    |> calculate_time()
  end

  def calculate_time(changeset) do
    start_time = get_field(changeset, :start)
    end_time   = get_field(changeset, :end)

    cond do
      !is_nil(start_time) and !is_nil(end_time) ->
        hours   = end_time.hour   - start_time.hour
        minutes = end_time.minute - start_time.minute
        cond do
          minutes < 0 ->
            changeset
            |> put_change(:hours,   hours   -  1)
            |> put_change(:minutes, minutes + 60)
          true -> 
            changeset
            |> put_change(:hours,   hours)
            |> put_change(:minutes, minutes)
        end
      !is_nil(end_time) ->
        changeset
        |> put_change(:hours,   end_time.hour)
        |> put_change(:minutes, end_time.minute)
      true -> 
        changeset
    end
  end
end
