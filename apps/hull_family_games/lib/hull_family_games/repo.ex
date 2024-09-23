defmodule HullFamilyGames.Repo do
  use Ecto.Repo,
    otp_app: :hull_family_games,
    adapter: Ecto.Adapters.MyXQL
end
