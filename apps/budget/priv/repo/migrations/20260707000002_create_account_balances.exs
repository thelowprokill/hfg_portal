defmodule Budget.Repo.Migrations.CreateAccountBalances do
  use Ecto.Migration

  def change do
    create table(:account_balances) do
      add(:account_id, references(:accounts, on_delete: :delete_all), null: false)
      add(:year, :integer, null: false)
      add(:month, :integer, null: false)
      add(:balance, :decimal, precision: 12, scale: 2, null: false, default: 0)

      timestamps()
    end

    create(index(:account_balances, [:account_id]))
    create(unique_index(:account_balances, [:account_id, :year, :month]))
  end
end
