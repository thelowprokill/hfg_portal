defmodule Budget.Repo.Migrations.DropYearMonthFromAccountBalances do
  use Ecto.Migration

  def up do
    execute(~s(UPDATE #{Application.get_env(:budget, Budget.Repo)[:migration_default_prefix]}.account_balances SET date = CURRENT_DATE WHERE date IS NULL))

    drop(unique_index(:account_balances, [:account_id, :year, :month]))

    alter table(:account_balances) do
      remove(:year)
      remove(:month)
      modify(:date, :date, null: false)
    end

    create(unique_index(:account_balances, [:account_id, :date]))
  end

  def down do
    drop(unique_index(:account_balances, [:account_id, :date]))

    alter table(:account_balances) do
      add(:year, :integer)
      add(:month, :integer)
      modify(:date, :date, null: true)
    end

    execute("""
    UPDATE #{Application.get_env(:budget, Budget.Repo)[:migration_default_prefix]}.account_balances
    SET year = EXTRACT(YEAR FROM date), month = EXTRACT(MONTH FROM date)
    WHERE date IS NOT NULL
    """)

    create(unique_index(:account_balances, [:account_id, :year, :month]))
  end
end
