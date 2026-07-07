defmodule Budget.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts) do
      add(:user_id, :integer, null: false)
      add(:name, :string, null: false)
      add(:type, :string, null: false)

      timestamps()
    end

    create(index(:accounts, [:user_id]))
  end
end
