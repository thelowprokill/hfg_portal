defmodule ItBudget.Repo do
  use Ecto.Repo,
    otp_app: :it_budget,
    adapter: Ecto.Adapters.MyXQL
end
