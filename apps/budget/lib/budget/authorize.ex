defmodule Budget.Authorize do
  alias HfgPortal.Helpers.Page
  alias Budget.Users.Roles

  @pages [
    %Page{id: "dashboard",          name: "Dashboard",          module: HfgPortalWeb.Budget.Dashboard.DashboardLive},
    %Page{id: "buckets",            name: "Buckets",            module: HfgPortalWeb.Budget.Buckets.BucketsLive},
    %Page{id: "scheduled_expenses", name: "Scheduled Expenses", module: HfgPortalWeb.Budget.ScheduledExpenses.ScheduledExpensesLive},
    %Page{id: "transactions",       name: "Transactions",       module: HfgPortalWeb.Budget.Transactions.TransactionsLive},
    %Page{id: "users",              name: "Users",              module: HfgPortalWeb.Budget.Users.UsersLive},
  ]

  def list_pages(user, dev_admin \\ false)
  def list_pages(%HfgPortal.Accounts.User{} = user, _),        do: list_pages(user.id, user.dev_admin && user.admin_mode)
  def list_pages(user_id, dev_admin) when is_integer(user_id), do: Budget.UserRoles.get(user_id, :user) |> list_pages(dev_admin)
  def list_pages(%Budget.Users.UserRole{} = user_role, dev_admin) do
    @pages |> Enum.filter(&authorize(user_role.role, &1.id, dev_admin))
  end
  def list_pages(_, true),  do: @pages
  def list_pages(_, _),     do: []

  def authorize(role, page, dev_admin \\ false)
  def authorize(%Roles{} = role, _page, dev_admin) do
    dev_admin || role.view
  end
  def authorize(%Budget.Users.UserRole{} = user_role, page, dev_admin), do: authorize(user_role.role, page, dev_admin)
  def authorize(role, page, dev_admin) when is_binary(role),            do: authorize(Roles.get(role), page, dev_admin)
  def authorize(_user, _page, _dev_admin),                              do: false
end
