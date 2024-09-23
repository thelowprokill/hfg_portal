defmodule AdminLogs.Repo.Migrations.CreatePythonScripts do
  use Ecto.Migration

  def change do
    create table(:python_scripts) do
      add :name,       :string
      add :sub_script, :string
      add :run_type,   :string
      add :duration,   :integer
      add :off_start,  :integer
      add :off_end,    :integer
      add :count,      :integer

      timestamps()
    end
  end
end
