defmodule Budget.Repo.Migrations.AddDateToAccountBalances do
  use Ecto.Migration

  def change do
    alter table(:account_balances) do
      add(:date, :date)
    end
  end
end
