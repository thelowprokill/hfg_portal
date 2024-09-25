defmodule LoanRepayment.Authorize do
  alias LoanRepayment.{
    Users.Roles,
  }
  alias HfgPortal.Helpers.Page

  @pages [
    %Page{id: "home",           name: "Home",           module: HfgPortalWeb.LoanRepayment.Home.HomeLive},
    #%Page{id: "reports",        name: "Reports",        module: HfgPortalWeb.LoanRepayment.Reports.ReportsLive},
    %Page{id: "users",          name: "Users",          module: HfgPortalWeb.LoanRepayment.Users.UsersLive},
  ]

  # pattern match on user struct
  def list_pages(user, dev_admin \\ false)
  def list_pages(%LoanRepayment.Users.User{} = user, _),                  do: list_pages(user.user_role, user.dev_admin && user.admin_mode)
  def list_pages(%HfgPortal.Accounts.User{} = user, _),                   do: list_pages(user.id, user.dev_admin && user.admin_mode)
  def list_pages(user_id, dev_admin) when is_integer(user_id),            do: LoanRepayment.UserRoles.get(user_id, :user) |> list_pages(dev_admin)
  def list_pages(%LoanRepayment.Users.UserRole{} = user_role, dev_admin), do: @pages |> Enum.filter(fn page -> authorize(user_role.role, page.id, dev_admin) end)

  def list_pages(_, true),  do: @pages
  def list_pages(_, false), do: []

  def authorize(role, page, dev_admin \\ false)
  def authorize(%LoanRepayment.Users.Roles{} = role, page, dev_admin) do
    cond do
      #user.dev_admin -> true
      dev_admin -> true
      role && role.edit  && page     in ["home", "reports"]    -> true
      role && role.view  && page     in ["home", "reports"]    -> true
      true -> false
    end
  end
  def authorize(%LoanRepayment.Users.UserRole{} = user_role, page, dev_admin), do: authorize(user_role.role, page, dev_admin)
  def authorize(%LoanRepayment.Users.User{} = user, page, _dev_admin), do: authorize((if Map.get(user, :user_role), do: user.user_role.role, else: "None"), page, user.dev_admin)
  def authorize(role, page, dev_admin) when is_binary(role), do: authorize(Roles.get(role), page, dev_admin)
  def authorize(_user, _page, _dev_admin), do: false
end
