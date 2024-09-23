defmodule HullFamilyGames.Authorize do

  alias HullFamilyGames.Accounts
  alias HullFamilyGames.Helpers.Page

  @pages [
    %Page{id: "home",         name: "Home",      module: HullFamilyGamesWeb.Accounts.Home.HomeLive},
    %Page{id: "api_accounts", name: "API Accounts", module: HullFamilyGamesWeb.Accounts.ApiAccounts.ApiAccountsLive},
    %Page{id: "locations",    name: "Locations",    module: HullFamilyGamesWeb.Accounts.Locations.LocationsLive},
  ]

  # pattern match on user struct
  def list_pages(user, dev_admin \\ false)
  def list_pages(user_id, dev_admin) when is_integer(user_id),       do: Accounts.get(user_id) |> list_pages(dev_admin)
  def list_pages(%HullFamilyGames.Accounts.User{} = user, _),              do: @pages |> Enum.filter(fn page -> authorize(user, page.id, user.admin_mode && (user.dev_admin || user.portal_admin)) end)

  def list_pages(_, true),  do: @pages
  def list_pages(_, false), do: []

  def authorize(user, page, dev_admin \\ false)
  def authorize(%HullFamilyGames.Accounts.User{} = _user, _page, dev_admin) do
    cond do
      dev_admin -> true
      true -> false
    end
  end
  def authorize(_user, _page, _dev_admin), do: false
end

