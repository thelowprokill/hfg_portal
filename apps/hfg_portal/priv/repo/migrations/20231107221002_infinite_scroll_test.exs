defmodule HfgPortal.Repo.Migrations.InfiniteScrollTest do
  use Ecto.Migration

  def change do
    create table(:infinite_scroll_test) do
      add :name, :string
      timestamps()
    end
  end
end
