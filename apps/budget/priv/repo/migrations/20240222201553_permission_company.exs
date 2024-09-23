defmodule Budget.Repo.Migrations.PermissionCompany do
  use Ecto.Migration

  def change do
    create table(:permission_company) do
      add :role_id,           references(:roles,           on_delete: :delete_all), null: false
      add :company_id,        references(:companies,       on_delete: :delete_all), null: false

      add :section,    :string
      add :permission, :string

      add :created_by_id, references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)
      add :updated_by_id, references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:permission_company, [:role_id, :company_id, :section], name: :permission_company_unique_index)
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
