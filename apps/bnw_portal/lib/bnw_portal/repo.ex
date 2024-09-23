defmodule BnwPortal.Repo do
  use Ecto.Repo,
    otp_app: :bnw_portal,
    adapter: Ecto.Adapters.MyXQL
end
