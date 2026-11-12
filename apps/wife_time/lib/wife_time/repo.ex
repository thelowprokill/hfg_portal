defmodule WifeTime.Repo do
  use Ecto.Repo,
    otp_app: :wife_time,
    adapter: Ecto.Adapters.Postgres
end
