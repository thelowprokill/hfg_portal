defmodule AdminLogs.Repo do
  use Ecto.Repo,
    otp_app: :admin_logs,
    adapter: Ecto.Adapters.MyXQL
end
