defmodule ItBudget.Repo.Migrations.Budgets do
  use Ecto.Migration

  def change do
    create table(:budgets) do
      add :year,        :integer

      add :description, :string
      add :user_id,     references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)))
      add :active,      :boolean, default: true, null: false

      timestamps()
    end

    create unique_index(:budgets, [:year], name: :uk_budget)
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
