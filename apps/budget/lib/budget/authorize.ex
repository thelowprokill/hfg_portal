defmodule Budget.Authorize do
  @roles Budget.Users.Roles
  @user Budget.Users.User
  @user_role Budget.Users.UserRole
  @user_roles Budget.UserRoles
  alias HfgPortal.Helpers.Page

  @pages [
    %Page{
      id: "dashboard",
      name: "Dashboard",
      module: HfgPortalWeb.Budget.Dashboard.DashboardLive
    },
    %Page{
      id: "balances",
      name: "Balances",
      module: HfgPortalWeb.Budget.Balances.BalancesLive
    },
    %Page{
      id: "manage",
      name: "Manage",
      links: [
        %Page{
          id: "accounts",
          name: "Accounts",
          module: HfgPortalWeb.Budget.Accounts.AccountsLive
        },
        %Page{id: "buckets", name: "Buckets", module: HfgPortalWeb.Budget.Buckets.BucketsLive},
        %Page{
          id: "scheduled_expenses",
          name: "Scheduled Expenses",
          module: HfgPortalWeb.Budget.ScheduledExpenses.ScheduledExpensesLive
        },
        %Page{
          id: "transactions",
          name: "Transactions",
          module: HfgPortalWeb.Budget.Transactions.TransactionsLive
        },
        %Page{id: "users", name: "Users", module: HfgPortalWeb.Budget.Users.UsersLive}
      ]
    }
  ]

  use HfgPortal.Helpers.DefaultAuthorize,
    roles: @roles,
    user: @user,
    user_role: @user_role,
    user_roles: @user_roles,
    pages: @pages

  def user_authorize(%@roles{} = role, page, dev_admin) do
    cond do
      dev_admin -> true
      role && role.admin && page not in ["reports"] -> true
      role && role.edit && page in ["dashboard", "balances"] -> true
      role && role.view && page in ["dashboard", "balances"] -> true
      true -> false
    end
  end

  def can_edit?(%HfgPortal.Accounts.User{} = user) do
    (user.dev_admin && user.admin_mode) || can_edit?(user.id)
  end

  def can_edit?(user_id) when is_integer(user_id) do
    case @user_roles.get(user_id, :user) do
      nil -> false
      user_role -> @roles.get(user_role.role).edit
    end
  end
end
