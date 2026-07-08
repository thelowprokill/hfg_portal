defmodule TaskAutomationController.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TaskAutomationController.Repo,
      {DNSCluster, query: Application.get_env(:task_automation_controller, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TaskAutomationController.PubSub}
      # Start a worker by calling: TaskAutomationController.Worker.start_link(arg)
      # {TaskAutomationController.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: TaskAutomationController.Supervisor)
  end
end
