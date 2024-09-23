defmodule Budget.Repo.Migrations.CreateDraftTypes do
  use Ecto.Migration

  def change do
    create table(:draft_types) do
      add :name,                :string, null: false
      add :order_number,        :integer, null: false
      add :instructions,        :text
      add :show_planning,       :boolean, null: false, default: true
      add :show_monthly_inputs, :boolean, null: false, default: true
      add :company_id,          references(:companies, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:draft_types, [:company_id, :name], name: :draft_type_unique_index)
    create unique_index(:draft_types, [:company_id, :order_number])
  end
end
