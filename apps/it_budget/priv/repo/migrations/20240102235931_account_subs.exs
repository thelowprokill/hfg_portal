defmodule ItBudget.Repo.Migrations.AccountSubs do
  use Ecto.Migration

  def change do
    create table(:account_subs) do
      add :name,        :string
      add :account_id,  references(:accounts, on_delete: :delete_all)
      add :locked,      :boolean, default: false

      add :description, :string
      add :user_id,     references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)
      add :active,      :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:account_subs, [:name, :account_id], name: :uk_acc_sub)
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
