defmodule DevTeamTimetracking.Repo.Migrations.CreateFixedProjects do
  use Ecto.Migration

  def change do
    create table(:fixed_projects) do
      add :name,            :string
      add :key,             :string
      add :description,     :text
      add :status,          :string
      add :project_percent, :integer
      add :created_by_id,   references(:users, prefix: account_prefix(Application.get_env(:dev_team_timetracking, :env)))

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
