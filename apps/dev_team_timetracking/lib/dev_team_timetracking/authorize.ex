defmodule DevTeamTimetracking.Authorize do
  alias DevTeamTimetracking.{
    Users.Roles,
  }
  alias BnwPortal.Helpers.Page

  @pages [
    %Page{id: "home",           name: "Home",           module: BnwPortalWeb.DevTeamTimetracking.Home.HomeLive},
    #%Page{id: "accounts",       name: "Accounts",       module: BnwPortalWeb.DevTeamTimetracking.Accounts.AccountsLive},
    #%Page{id: "budgets",        name: "Budgets",        module: BnwPortalWeb.DevTeamTimetracking.Budgets.BudgetsLive},
    %Page{id: "reports",        name: "Reports",        module: BnwPortalWeb.DevTeamTimetracking.Reports.ReportsLive},
    %Page{id: "fixed_projects", name: "Fixed Projects", module: BnwPortalWeb.DevTeamTimetracking.FixedProjects.FixedProjectsLive},
    %Page{id: "users",          name: "Users",          module: BnwPortalWeb.DevTeamTimetracking.Users.UsersLive},
  ]

  # pattern match on user struct
  def list_pages(user, dev_admin \\ false)
  def list_pages(%DevTeamTimetracking.Users.User{} = user, _),                  do: list_pages(user.user_role, user.dev_admin && user.admin_mode)
  def list_pages(%BnwPortal.Accounts.User{} = user, _),                         do: list_pages(user.id, user.dev_admin && user.admin_mode)
  def list_pages(user_id, dev_admin) when is_integer(user_id),                  do: DevTeamTimetracking.UserRoles.get(user_id, :user) |> list_pages(dev_admin)
  def list_pages(%DevTeamTimetracking.Users.UserRole{} = user_role, dev_admin), do: @pages |> Enum.filter(fn page -> authorize(user_role.role, page.id, dev_admin) end)

  def list_pages(_, true),  do: @pages
  def list_pages(_, false), do: []

  def authorize(role, page, dev_admin \\ false)
  def authorize(%DevTeamTimetracking.Users.Roles{} = role, page, dev_admin) do
    cond do
      #user.dev_admin -> true
      dev_admin -> true
      role && role.edit  && page     in ["home", "reports"]    -> true
      role && role.view  && page     in ["home", "reports"]    -> true
      true -> false
    end
  end
  def authorize(%DevTeamTimetracking.Users.UserRole{} = user_role, page, dev_admin), do: authorize(user_role.role, page, dev_admin)
  def authorize(%DevTeamTimetracking.Users.User{} = user, page, _dev_admin), do: authorize((if Map.get(user, :user_role), do: user.user_role.role, else: "None"), page, user.dev_admin)
  def authorize(role, page, dev_admin) when is_binary(role), do: authorize(Roles.get(role), page, dev_admin)
  def authorize(_user, _page, _dev_admin), do: false
end
