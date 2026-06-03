defmodule Budget.Repo.Migrations.AddCreatedByToTransactions do
  use Ecto.Migration

  def change do
    alter table(:transactions) do
      add :created_by_id, references(:users, prefix: hfg_portal_prefix(Application.get_env(:budget, :env)), on_delete: :nothing)
    end

    create index(:transactions, [:created_by_id])
  end

  defp hfg_portal_prefix(:dev),  do: "hfg_portal_dev"
  defp hfg_portal_prefix(:test), do: "hfg_portal_test"
  defp hfg_portal_prefix(_),     do: "hfg_portal"
end
