defmodule Budget.Repo.Migrations.CreateUserRoles do
  use Ecto.Migration

  def change do
    create table(:user_roles) do
      add :user_id, references(:users, prefix: hfg_portal_prefix(Application.get_env(:budget, :env)))
      add :role,    :string

      timestamps()
    end

    create unique_index(:user_roles, [:user_id])
  end

  defp hfg_portal_prefix(:dev),  do: "hfg_portal_dev"
  defp hfg_portal_prefix(:test), do: "hfg_portal_test"
  defp hfg_portal_prefix(_),     do: "hfg_portal"
end
