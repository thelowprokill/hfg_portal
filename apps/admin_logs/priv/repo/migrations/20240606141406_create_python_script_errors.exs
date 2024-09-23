defmodule AdminLogs.Repo.Migrations.CreatePythonScriptErrors do
  use Ecto.Migration

  def change do
    create table(:python_script_errors) do
      add :errors, :integer
      add :python_script_id, references(:python_scripts, on_delete: :delete_all)

      timestamps()
    end
  end
end
