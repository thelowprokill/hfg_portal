defmodule WifeTime.Repo.Migrations.WifeTimes do
  use Ecto.Migration

  def change do
    create table(:wife_times) do
      add :entry_date,  :date
      add :happened,    :boolean
      add :menstration, :boolean, default: false
      add :comment,     :string

      add :created_by_id, references(:users, prefix: account_prefix(Application.get_env(:wife_time, :env)))
      add :updated_by_id, references(:users, prefix: account_prefix(Application.get_env(:wife_time, :env)))

      timestamps()
    end
  end

  defp account_prefix(:dev),  do: "hfg_portal_dev"
  defp account_prefix(:test), do: "hfg_portal_test"
  defp account_prefix(_),     do: "hfg_portal"
end
