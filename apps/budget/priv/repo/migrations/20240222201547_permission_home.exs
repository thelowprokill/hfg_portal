defmodule Budget.Repo.Migrations.PermissionHome do
  use Ecto.Migration

  def change do
    create table(:permission_home) do
      add :role_id,           references(:roles,           on_delete: :delete_all), null: false
      add :company_id,        references(:companies,       on_delete: :delete_all), null: false
      add :location_id,       references(:locations,       on_delete: :delete_all)
      add :company_budget_id, references(:company_budgets, on_delete: :delete_all)
      add :draft_type_id,     references(:draft_types,     on_delete: :delete_all)
      add :draft_id,          references(:drafts,          on_delete: :delete_all)

      add :section,    :string
      add :permission, :string

      add :created_by_id, references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)
      add :updated_by_id, references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:permission_home, [:role_id, :company_id, :location_id, :company_budget_id, :draft_type_id, :draft_id, :section], name: :permission_home_unique_index)
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
