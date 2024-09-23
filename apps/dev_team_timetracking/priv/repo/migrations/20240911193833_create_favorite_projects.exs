defmodule DevTeamTimetracking.Repo.Migrations.CreateFavoriteProjects do
  use Ecto.Migration

  def change do
    create table(:favorite_projects) do
      add :user_id,    references(:users, prefix: account_prefix(Application.get_env(:dev_team_timetracking, :env)))
      add :project_id, references(:zoho_projects, prefix: "bnw_dashboard_plugs_app", on_delete: :delete_all)
      add :fixed_project_id, references(:fixed_projects, on_delete: :delete_all)

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
