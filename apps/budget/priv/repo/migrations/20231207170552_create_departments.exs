defmodule Budget.Repo.Migrations.Departments do
  use Ecto.Migration

  def change do
    create table(:departments) do
      add :name,                 :string, null: false
      add :department_number,    :string, null: false
      add :external_code,        :string
      add :active,               :boolean, default: true, null: false
      add :company_id,           references(:companies, on_delete: :delete_all)
      add :variable_input_id,    references(:variable_inputs, on_delete: :restrict)
      add :variable_input_name,  :string
      add :exclude_from_yardage, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:departments, [:company_id, :department_number, :name], name: :departments_unique_index)
    create unique_index(:departments, [:company_id, :name], name: :departments_unique_name_index)
    create unique_index(:departments, [:company_id, :department_number], name: :departments_unique_number_index)
  end
end
