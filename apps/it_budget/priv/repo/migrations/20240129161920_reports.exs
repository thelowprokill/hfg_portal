defmodule ItBudget.Repo.Migrations.Reports do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :report_name, :string
      add :report_url,  :string
      add :user_id,     references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)
      add :active,      :boolean, default: true, null: false

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
