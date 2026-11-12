defmodule LoanRepayment.Repo do
  use Ecto.Repo,
    otp_app: :loan_repayment,
    adapter: Ecto.Adapters.Postgres
end
