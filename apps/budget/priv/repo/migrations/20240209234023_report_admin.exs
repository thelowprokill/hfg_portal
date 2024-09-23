defmodule Budget.Repo.Migrations.ReportAdmin do
  use Ecto.Migration

  def change do
    create table(:report_admin) do
      add :username, :string
      add :password, :string
      add :active,   :boolean, default: true, null: false

      timestamps()
    end
  end
end
