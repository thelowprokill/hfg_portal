defmodule ItBudget.Repo.Migrations.BudgetAccounts do
  use Ecto.Migration

  def change do
    create table(:budget_accounts) do
      add :budget_id,      references(:budgets,      on_delete: :delete_all)
      add :account_sub_id, references(:account_subs, on_delete: :delete_all)
      add :month_0,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_1,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_2,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_3,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_4,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_5,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_6,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_7,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_8,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_9,        :decimal, precision: 12, scale: 2, default: 0.00
      add :month_10,       :decimal, precision: 12, scale: 2, default: 0.00
      add :month_11,       :decimal, precision: 12, scale: 2, default: 0.00

      add :description,    :string
      add :user_id,        references(:users, prefix: account_prefix(Application.get_env(:it_budget, :env)), on_delete: :delete_all)
      add :active,         :boolean, default: true, null: false

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "bnw_portal_dev"
  defp account_prefix(:test), do: "bnw_portal_test"
  defp account_prefix(_),     do: "bnw_portal"
end
