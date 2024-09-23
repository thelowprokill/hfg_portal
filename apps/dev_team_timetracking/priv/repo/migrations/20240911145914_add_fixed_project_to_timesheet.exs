defmodule DevTeamTimetracking.Repo.Migrations.AddFixedProjectToTimesheet do
  use Ecto.Migration

  def change do
    alter table(:timesheets) do
      add :fixed_project_id, references(:fixed_projects, on_delete: :delete_all), after: :project_id
    end
  end
end
