defmodule DevTeamTimetracking.Repo.Migrations.CreateTimesheets do
  use Ecto.Migration

  def change do
    create table(:timesheets) do
      add :entry_date, :date
      add :start,      :time
      add :end,        :time
      add :hours,      :integer
      add :minutes,    :integer
      add :task_key,   :string
      add :comments,   :text
      add :user_id,    references(:users, prefix: account_prefix(Application.get_env(:dev_team_timetracking, :env)))
      add :project_id, references(:zoho_projects, prefix: "bnw_dashboard_plugs_app")

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
