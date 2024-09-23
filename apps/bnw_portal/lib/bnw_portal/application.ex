defmodule BnwPortal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      BnwPortal.Repo,
      # Start the PubSub system
      {Phoenix.PubSub, name: BnwPortal.PubSub},
      # Start Finch
      {Finch, name: BnwPortal.Finch}
      # Start a worker by calling: BnwPortal.Worker.start_link(arg)
      # {BnwPortal.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BnwPortal.Supervisor)
  end
end
