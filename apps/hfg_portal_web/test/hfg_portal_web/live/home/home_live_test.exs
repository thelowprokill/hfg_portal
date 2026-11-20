defmodule HfgPortalWeb.Home.HomeLiveTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortalWeb.LiveFixtures2

  setup :register_and_log_in_user

  test "/ shows the portal home", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/")
    home = find_live_child(view, "root")
    assert home.module == HfgPortalWeb.Home.HomeLive
    assert render(home) =~ "Welcome to Hull Family Games Portal"
  end

  test "an unknown or forbidden page falls back to home with a message", %{conn: conn} do
    {view, home} = open_page(conn, "nope,nothing")
    assert home.module == HfgPortalWeb.Home.HomeLive
    assert render(view) =~ "does not exist or you lack the permissions"
  end

  test "the home page itself has no error message", %{conn: conn} do
    {view, _home} = open_page(conn, "home")
    refute render(view) =~ "lack the permissions"
  end

  test "logged out visitors are sent to log in" do
    assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(build_conn(), "/")
  end

  test "keeps working when the current user is updated", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, "/")
    home = find_live_child(view, "root")

    {:ok, _} = HfgPortal.Accounts.create_or_update(user, %{first_name: "Renamed"})
    send(home.pid, {[:user, :updated], %{user | first_name: "Renamed"}})
    assert render(home) =~ "Welcome"
  end
end
