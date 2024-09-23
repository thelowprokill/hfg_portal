defmodule Budget.Repo.Migrations.Roles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name,       :string
      add :active,     :boolean
      add :company_id, references(:companies, on_delete: :delete_all)

      add :created_by_id, references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)
      add :updated_by_id, references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:roles, [:company_id, :name], name: :roles_unique_index)
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
