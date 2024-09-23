defmodule Budget.Repo.Migrations.ReportAdjustment do
  use Ecto.Migration

  def change do
    alter table(:reports) do
      remove :report_title
      add :report_name, :string, before: :report_url
      add :active,      :boolean, default: true, null: false, after: :report_url
      add :user_id,     references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)
    end
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
