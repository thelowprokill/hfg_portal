defmodule ItBudget.Repo.Migrations.Accounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add :name, :string
      add :code, :string

      add :description, :string
      add :user_id, references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)
      add :active, :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:accounts, [:name], name: :uk_acc)
    create unique_index(:accounts, [:code], name: :uk_acc_code)
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
