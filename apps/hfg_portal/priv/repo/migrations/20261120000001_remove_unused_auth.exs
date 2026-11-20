defmodule HfgPortal.Repo.Migrations.RemoveUnusedAuth do
  use Ecto.Migration

  # API users and customers were never used, and the app sends no email: users are added by an
  # admin and sign in with a username and password. `down` puts the tables and columns back
  # empty; the data is not recoverable.

  def up do
    drop table(:api_users_tokens)
    drop table(:api_users)
    drop table(:customers_tokens)
    drop table(:customers)

    alter table(:users) do
      remove :email
      remove :confirmed_at
    end

    alter table(:users_tokens) do
      remove :sent_to
    end
  end

  def down do
    alter table(:users_tokens) do
      add :sent_to, :string
    end

    alter table(:users) do
      add :email, :string
      add :confirmed_at, :naive_datetime
    end

    create unique_index(:users, [:email])

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
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:customers_tokens, [:customer_id])
    create unique_index(:customers_tokens, [:context, :token])

    create table(:api_users) do
      add :username, :string, null: false
      add :email, :string
      add :name, :string
      add :first_name, :string
      add :middle_name, :string
      add :last_name, :string
      add :active, :boolean, default: true
      add :attempted_login, :integer, default: 0
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:api_users, [:email])

    create table(:api_users_tokens) do
      add :api_user_id, references(:api_users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:api_users_tokens, [:api_user_id])
    create unique_index(:api_users_tokens, [:context, :token])
  end
end
