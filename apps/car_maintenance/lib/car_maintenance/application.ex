defmodule CarMaintenance.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CarMaintenance.Repo,
      {DNSCluster, query: Application.get_env(:car_maintenance, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: CarMaintenance.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: CarMaintenance.Finch}
      # Start a worker by calling: CarMaintenance.Worker.start_link(arg)
      # {CarMaintenance.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CarMaintenance.Supervisor)
  end
end
