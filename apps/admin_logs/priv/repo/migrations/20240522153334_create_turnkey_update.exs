defmodule AdminLogs.Repo.Migrations.CreateTurnkeyUpdate do
  use Ecto.Migration

  def change do
    create table(:turnkey_updates) do
      add :table,  :string
      add :errors, :integer

      timestamps()
    end
  end
end
