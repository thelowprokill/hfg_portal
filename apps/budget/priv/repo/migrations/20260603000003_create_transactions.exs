defmodule Budget.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :bucket_id,            references(:buckets, on_delete: :delete_all),           null: false
      add :scheduled_expense_id, references(:scheduled_expenses, on_delete: :nilify_all)
      add :amount,               :decimal, precision: 12, scale: 2, null: false
      add :description,          :string,  null: false
      add :transaction_date,     :date,    null: false
      add :type,                 :string,  null: false

      timestamps()
    end

    create index(:transactions, [:bucket_id])
    create index(:transactions, [:scheduled_expense_id])
    create index(:transactions, [:transaction_date])
  end
end
