defmodule DevTeamTimetracking.Repo do
  use Ecto.Repo,
    otp_app: :dev_team_timetracking,
    adapter: Ecto.Adapters.MyXQL
end
