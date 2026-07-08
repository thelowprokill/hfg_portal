defmodule TaskAutomationController.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :name,         :string
      add :description,  :string
      add :priority_id,  references(:priorities, on_delete: :delete_all)
      add :address,      :string
      add :asynchronous, :boolean, default: false
      add :avg_runtime,  :integer

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
