defmodule HfgPortal.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute("CREATE SCHEMA IF NOT EXISTS \"#{Application.get_env(:hfg_portal, HfgPortal.Repo)[:migration_default_prefix]}\"", "")

    create table(:users) do
      add :username, :string, null: false
      add :email, :string
      add :first_name, :string
      add :middle_name, :string
      add :last_name, :string
      add :active, :boolean, default: true
      add :portal_admin, :boolean, default: false
      add :dev_admin, :boolean, default: false
      add :test_user, :boolean, default: false
      add :generic_user, :boolean, default: false
      add :attempted_login, :integer, default: 0
      add :confirmed_at, :naive_datetime
      add :start_date, :date
      add :end_date, :date
      add :hashed_password, :string, null: false
      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
