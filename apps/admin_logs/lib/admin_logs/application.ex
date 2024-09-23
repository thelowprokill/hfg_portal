defmodule AdminLogs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AdminLogs.Repo,
      {DNSCluster, query: Application.get_env(:admin_logs, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AdminLogs.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: AdminLogs.Finch}
      # Start a worker by calling: AdminLogs.Worker.start_link(arg)
      # {AdminLogs.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: AdminLogs.Supervisor)
  end
end
