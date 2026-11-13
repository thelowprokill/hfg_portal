defmodule HfgPortal.Repo do
  use Ecto.Repo,
    otp_app: :hfg_portal,
    adapter: Ecto.Adapters.Postgres
end
