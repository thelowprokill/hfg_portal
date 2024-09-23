defmodule BnwPortal.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @apps [
    :bnw_portal,
  ]

  def migrate do
    for app <- @apps do
      load_app(app)

      for repo <- repos(app) do
        # Create database schema
        repo.__adapter__.storage_up(repo.config)
        # Migrate
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
      end
    end
  end

  def rollback(repo, version, app) do
    load_app(app)
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos(app) do
    Application.fetch_env!(app, :ecto_repos)
  end

  defp load_app(app) do
    Application.load(app)
  end
end
