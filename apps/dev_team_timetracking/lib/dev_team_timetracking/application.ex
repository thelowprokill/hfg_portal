defmodule DevTeamTimetracking.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      DevTeamTimetracking.Repo,
      {DNSCluster, query: Application.get_env(:dev_team_timetracking, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DevTeamTimetracking.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: DevTeamTimetracking.Finch}
      # Start a worker by calling: DevTeamTimetracking.Worker.start_link(arg)
      # {DevTeamTimetracking.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: DevTeamTimetracking.Supervisor)
  end
end
