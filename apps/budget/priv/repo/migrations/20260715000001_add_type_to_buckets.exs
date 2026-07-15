defmodule Budget.Repo.Migrations.AddTypeToBuckets do
  use Ecto.Migration

  def up do
    alter table(:buckets) do
      add :type, :string, null: false, default: "normal"
    end

    execute("UPDATE buckets SET type = 'sinking_fund' WHERE monthly_contribution IS NOT NULL")
  end

  def down do
    alter table(:buckets) do
      remove :type
    end
  end
end
