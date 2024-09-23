defmodule BnwPortalWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      BnwPortalWeb.Telemetry,
      # Start the Endpoint (http/https)
      BnwPortalWeb.Endpoint
      # Start a worker by calling: BnwPortalWeb.Worker.start_link(arg)
      # {BnwPortalWeb.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BnwPortalWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BnwPortalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
