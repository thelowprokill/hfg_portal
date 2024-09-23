defmodule Budget.Repo.Migrations.CreateReports do
  use Ecto.Migration

  def change do
    create table(:reports) do
      add :report_title, :string
      add :report_url,   :text

      timestamps()
    end
  end
end
