defmodule HommSaves.Repo.Migrations.UserRoles do
  use Ecto.Migration

  def change do
    execute("CREATE SCHEMA IF NOT EXISTS \"#{Application.get_env(:homm_saves, HommSaves.Repo)[:migration_default_prefix]}\"", "")

    create table(:user_roles) do
      add :user_id, references(:users, prefix: account_prefix(Application.get_env(:homm_saves, :env)))
      add :role,    :string

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hfg_portal_dev"
  defp account_prefix(:test), do: "hfg_portal_test"
  defp account_prefix(_),     do: "hfg_portal"
end
