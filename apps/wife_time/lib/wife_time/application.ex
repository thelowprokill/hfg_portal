defmodule WifeTime.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WifeTime.Repo,
      {DNSCluster, query: Application.get_env(:wife_time, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WifeTime.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: WifeTime.Finch}
      # Start a worker by calling: WifeTime.Worker.start_link(arg)
      # {WifeTime.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: WifeTime.Supervisor)
  end
end
