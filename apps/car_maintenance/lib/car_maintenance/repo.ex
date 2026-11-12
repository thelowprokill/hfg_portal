defmodule CarMaintenance.Repo do
  use Ecto.Repo,
    otp_app: :car_maintenance,
    adapter: Ecto.Adapters.Postgres
end
