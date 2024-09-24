defmodule HfgPortal.Repo.Migrations.CreateApiUsersAuthTables do
  use Ecto.Migration

  def change do
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
      add :token, :binary, null: false, size: 32
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:api_users_tokens, [:api_user_id])
    create unique_index(:api_users_tokens, [:context, :token])
  end
end
