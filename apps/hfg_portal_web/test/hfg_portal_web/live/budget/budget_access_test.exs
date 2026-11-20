defmodule HfgPortalWeb.Budget.AccessTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortal.AccountsFixtures
  import HfgPortalWeb.LiveHelpers

  @home HfgPortalWeb.Home.HomeLive

  @pages %{
    "budget,dashboard"                 => HfgPortalWeb.Budget.Dashboard.DashboardLive,
    "budget,balances"                  => HfgPortalWeb.Budget.Balances.BalancesLive,
    "budget,manage,accounts"           => HfgPortalWeb.Budget.Accounts.AccountsLive,
    "budget,manage,buckets"            => HfgPortalWeb.Budget.Buckets.BucketsLive,
    "budget,manage,scheduled_expenses" => HfgPortalWeb.Budget.ScheduledExpenses.ScheduledExpensesLive,
    "budget,manage,transactions"       => HfgPortalWeb.Budget.Transactions.TransactionsLive,
    "budget,manage,users"              => HfgPortalWeb.Budget.Users.UsersLive
  }

  @viewer_pages ["budget,dashboard", "budget,balances"]

  for {role, allowed} <- [{nil, []}, {"None", []}, {"View", @viewer_pages}, {"Edit", @viewer_pages}, {"Admin", :all}] do
    test "#{role || "no"} role reaches exactly its pages", %{conn: conn} do
      user = user_fixture()
      if unquote(role), do: budget_role(user, unquote(role))
      conn = log_in(conn, user)

      allowed = if unquote(allowed) == :all, do: Map.keys(@pages), else: unquote(allowed)

      for {page, module} <- @pages do
        expected = if page in allowed, do: module, else: @home
        assert rendered_module(conn, page) == expected, "#{page} for #{unquote(role)}"
      end
    end
  end

  test "dev admin in admin mode reaches every page without a role", %{conn: conn} do
    conn = log_in(conn, user_fixture(%{dev_admin: true}))

    for {page, module} <- @pages do
      assert rendered_module(conn, page, "&admin=true") == module
    end
  end

  test "portal admin gets nothing in budget without a role", %{conn: conn} do
    conn = log_in(conn, user_fixture(%{portal_admin: true}))

    for {page, _} <- @pages, do: assert(rendered_module(conn, page, "&admin=true") == @home)
  end

  test "the manage section is only listed for admins", %{conn: conn} do
    viewer = user_fixture()
    budget_role(viewer, "Edit")
    {:ok, view, _} = conn |> log_in(viewer) |> live("/?page=budget,dashboard")
    refute has_element?(view, "a[phx-value-link='budget,manage']")

    admin = user_fixture()
    budget_role(admin, "Admin")
    {:ok, view, _} = build_conn() |> log_in(admin) |> live("/?page=budget,dashboard")
    assert has_element?(view, "a[phx-value-link='budget,manage']")
  end
end
