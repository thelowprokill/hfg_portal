defmodule ItBudget.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ItBudget.Repo,
      {DNSCluster, query: Application.get_env(:it_budget, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ItBudget.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: ItBudget.Finch}
      # Start a worker by calling: ItBudget.Worker.start_link(arg)
      # {ItBudget.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: ItBudget.Supervisor)
  end
end
