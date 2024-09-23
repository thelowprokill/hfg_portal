defmodule Budget.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Budget.Repo,
      {DNSCluster, query: Application.get_env(:budget, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Budget.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Budget.Finch}
      # Start a worker by calling: Budget.Worker.start_link(arg)
      # {Budget.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Budget.Supervisor)
  end
end
