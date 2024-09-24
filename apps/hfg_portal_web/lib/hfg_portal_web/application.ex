defmodule HfgPortalWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      HfgPortalWeb.Telemetry,
      # Start the Endpoint (http/https)
      HfgPortalWeb.Endpoint
      # Start a worker by calling: HfgPortalWeb.Worker.start_link(arg)
      # {HfgPortalWeb.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: HfgPortalWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    HfgPortalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
