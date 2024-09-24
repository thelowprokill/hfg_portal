defmodule CarMaintenance.Repo.Migrations.CreateUserRoles do
  use Ecto.Migration

  def change do
    create table(:user_roles) do
      add :user_id,    references(:users, prefix: account_prefix(Application.get_env(:car_maintenance, :env)))
      add :role,       :string

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hull_family_games_dev"
  defp account_prefix(:test), do: "hull_family_games_test"
  defp account_prefix(_),     do: "hull_family_games"
end
