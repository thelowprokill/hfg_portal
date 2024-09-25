defmodule LoanRepayment.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LoanRepayment.Repo,
      {DNSCluster, query: Application.get_env(:loan_repayment, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: LoanRepayment.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: LoanRepayment.Finch}
      # Start a worker by calling: LoanRepayment.Worker.start_link(arg)
      # {LoanRepayment.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: LoanRepayment.Supervisor)
  end
end
