defmodule HfgPortal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      HfgPortal.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: HfgPortal.PubSub},
      # Start Finch
      {Finch, name: HfgPortal.Finch}
      # Start a worker by calling: HfgPortal.Worker.start_link(arg)
      # {HfgPortal.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: HfgPortal.Supervisor)
  end
end
