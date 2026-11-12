defmodule Timekeeping.Repo do
  use Ecto.Repo,
    otp_app: :timekeeping,
    adapter: Ecto.Adapters.Postgres
end
