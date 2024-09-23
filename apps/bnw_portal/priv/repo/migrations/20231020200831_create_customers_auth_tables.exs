defmodule BnwPortal.Repo.Migrations.CreateCustomersAuthTables do
  use Ecto.Migration

  def change do
    create table(:customers) do
      add :email, :string, null: false, size: 160
      add :attempted_login, :integer, default: 0
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:customers, [:email])

    create table(:customers_tokens) do
      add :customer_id, references(:customers, on_delete: :delete_all), null: false
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:customers_tokens, [:customer_id])
    create unique_index(:customers_tokens, [:context, :token])
  end
end
