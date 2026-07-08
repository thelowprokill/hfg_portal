defmodule TaskAutomationController.Repo.Migrations.CreateQueue do
  use Ecto.Migration

  def change do
    create table(:queue) do
      add :job_id,     references(:jobs, on_delete: :delete_all)
      add :machine_id, references(:machines, on_delete: :delete_all)


      add :status,       :string
      add :started_at,   :naive_datetime
      add :completed_at, :naive_datetime
      add :runtime,      :integer
      add :type,         :string
      add :user_id,      references(:users, prefix: account_prefix(Application.get_env(:task_automation_controller, :env)), on_delete: :delete_all)

      add :created_by_id, references(:users, prefix: account_prefix(Application.get_env(:task_automation_controller, :env)), on_delete: :delete_all)
      add :updated_by_id, references(:users, prefix: account_prefix(Application.get_env(:task_automation_controller, :env)), on_delete: :delete_all)
      add :active, :boolean, default: true, null: false

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hfg_portal_dev"
  defp account_prefix(:test), do: "hfg_portal_test"
  defp account_prefix(_),     do: "hfg_portal"
end
