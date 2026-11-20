defmodule HommSaves.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HommSaves.Repo,
      {DNSCluster, query: Application.get_env(:homm_saves, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: HommSaves.PubSub},
      # Start a worker by calling: HommSaves.Worker.start_link(arg)
      # {HommSaves.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: HommSaves.Supervisor)
  end
end
