defmodule Budget.Repo.Migrations.ReportingInputs do
  use Ecto.Migration

  def change do
    create table(:reporting_inputs) do
      add :name,       :string, null: false
      add :active,     :boolean, default: true, null: false
      add :company_id, references(:companies, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:reporting_inputs, [:name, :company_id], name: :reporting_inputs_unique_index)
  end
end
