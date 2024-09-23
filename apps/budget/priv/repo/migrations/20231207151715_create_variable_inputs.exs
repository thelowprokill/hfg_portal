defmodule Budget.Repo.Migrations.VariableInputs do
  use Ecto.Migration

  def change do
    create table(:variable_inputs) do
      add :name,       :string, null: false
      add :active,     :boolean, default: true, null: false
      add :misc,       :boolean, default: false, null: false
      add :company_id, references(:companies, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:variable_inputs, [:name, :company_id], name: :variable_inputs_unique_index)

  end
end
