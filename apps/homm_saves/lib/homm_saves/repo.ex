defmodule HommSaves.Repo do
  use Ecto.Repo,
    otp_app: :homm_saves,
    adapter: Ecto.Adapters.Postgres
end
