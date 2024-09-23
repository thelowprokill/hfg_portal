defmodule DevTeamTimetracking.Repo.Migrations.CreateCapacity do
  use Ecto.Migration

  def change do
    create table(:capacities) do
      add :user_id,    references(:users, prefix: account_prefix(Application.get_env(:dev_team_timetracking, :env)))
      add :monday,     :date
      add :capacity,   :integer

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
