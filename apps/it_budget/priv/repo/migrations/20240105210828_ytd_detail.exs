defmodule ItBudget.Repo.Migrations.YtdDetail do
  use Ecto.Migration

  def change do
    create table(:ytd_detail) do
      add :budget_id,        references(:budgets, on_delete: :delete_all)
      add :account_id,       references(:accounts, on_delete: :delete_all)
      add :amount,           :decimal, precision: 12, scale: 2, default: 0.00
      add :trx_date,         :date
      add :period,           :integer
      add :description,      :string
      add :detail_reference, :string

      timestamps()
    end
  end
end
