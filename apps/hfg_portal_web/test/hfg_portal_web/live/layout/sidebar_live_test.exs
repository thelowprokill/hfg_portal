defmodule HfgPortalWeb.Layout.SidebarLiveTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortal.AccountsFixtures
  import HfgPortalWeb.LiveHelpers

  alias HfgPortal.Accounts

  @denied "The page you requested does not exist or you lack the permissions to access it."

  describe "authentication" do
    test "anonymous users are sent to the log in page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, "/")
    end

    test "a logged in user gets the sidebar with their name and the home page", %{conn: conn} do
      user = user_fixture(%{first_name: "Ada", last_name: "Lovelace"})
      {:ok, view, html} = conn |> log_in(user) |> live("/")

      assert html =~ "Ada"
      assert html =~ "Lovelace"
      assert has_element?(view, "#sidebar")
      assert find_live_child(view, "root").module == HfgPortalWeb.Home.HomeLive
    end

    test "an inactive user gets no page, only the forced log out link", %{conn: conn} do
      user = user_fixture(%{active: false})
      {:ok, view, _html} = conn |> log_in(user) |> live("/")

      assert has_element?(view, "#force_log_out_button")
      refute has_element?(view, "#sidebar")
      refute find_live_child(view, "root")
    end

    test "a user deactivated while signed in loses the page right away", %{conn: conn} do
      user = user_fixture()
      {view, _child} = conn |> log_in(user) |> open_page("home")
      assert has_element?(view, "#sidebar")

      {:ok, _} = Accounts.deactivate(user.id)

      assert has_element?(view, "#force_log_out_button")
      refute has_element?(view, "#sidebar")
    end
  end

  describe "page selection" do
    test "an unknown page falls back to home with an error", %{conn: conn} do
      conn = log_in(conn, user_fixture())
      {:ok, view, html} = live(conn, "/?page=nope,nothing")

      assert html =~ @denied
      assert find_live_child(view, "root").module == HfgPortalWeb.Home.HomeLive
    end

    test "apps the user has no role in are not listed", %{conn: conn} do
      {:ok, view, _html} = conn |> log_in(user_fixture()) |> live("/")

      for app <- ~w(budget homm_saves task_automation_controller accounts dev_tools) do
        refute has_element?(view, "a[phx-value-link='#{app}']"), "#{app} should be hidden"
      end
    end

    test "an app shows once the user has a role in it", %{conn: conn} do
      user = user_fixture()
      budget_role(user, "View")
      {:ok, view, _html} = conn |> log_in(user) |> live("/")

      assert has_element?(view, "a[phx-value-link='budget']")
      refute has_element?(view, "a[phx-value-link='homm_saves']")
    end

    test "select_section expands an app and selecting it again collapses it", %{conn: conn} do
      user = user_fixture()
      budget_role(user, "View")
      {:ok, view, _html} = conn |> log_in(user) |> live("/")

      refute has_element?(view, "a[href='/?page=budget,dashboard']")

      view |> element("a[phx-value-link='budget']") |> render_click()
      assert has_element?(view, "a[href='/?page=budget,dashboard']")
      assert has_element?(view, "a[href='/?page=budget,balances']")
      # Manage (admin only) is not offered to a viewer
      refute has_element?(view, "a[phx-value-link='budget,manage']")

      view |> element("a[phx-value-link='budget']") |> render_click()
      refute has_element?(view, "a[href='/?page=budget,dashboard']")
    end

    test "page links keep admin mode on", %{conn: conn} do
      user = user_fixture(%{dev_admin: true})
      {:ok, view, _html} = conn |> log_in(user) |> live("/?admin=true")

      view |> element("a[phx-value-link='budget']") |> render_click()
      assert has_element?(view, "a[href='/?page=budget,dashboard&admin=true']")
    end

    test "the sidebar can be hidden and shown", %{conn: conn} do
      {:ok, view, _html} = conn |> log_in(user_fixture()) |> live("/")

      render_click(view, "hide_sidebar")
      refute has_element?(view, "nav#sidebar")
      assert has_element?(view, "div#sidebar")

      render_click(view, "show_sidebar")
      assert has_element?(view, "nav#sidebar")
    end
  end

  describe "admin mode" do
    test "is only offered to portal and dev admins", %{conn: conn} do
      {:ok, view, _} = conn |> log_in(user_fixture()) |> live("/")
      refute has_element?(view, "[phx-click='toggle_admin_mode']")

      {:ok, view, _} = build_conn() |> log_in(user_fixture(%{portal_admin: true})) |> live("/")
      assert has_element?(view, "[phx-click='toggle_admin_mode']")
    end

    test "a crafted ?admin=true gives a normal user nothing", %{conn: conn} do
      conn = log_in(conn, user_fixture())

      assert rendered_module(conn, "accounts,home", "&admin=true") == HfgPortalWeb.Home.HomeLive
      assert rendered_module(conn, "dev_tools,input_gallery", "&admin=true") == HfgPortalWeb.Home.HomeLive
      assert rendered_module(conn, "budget,dashboard", "&admin=true") == HfgPortalWeb.Home.HomeLive
    end

    test "dev admins only reach app pages without a role in admin mode", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{dev_admin: true}))

      assert rendered_module(conn, "budget,manage,users") == HfgPortalWeb.Home.HomeLive
      assert rendered_module(conn, "budget,manage,users", "&admin=true") == HfgPortalWeb.Budget.Users.UsersLive
    end

    test "portal admins in admin mode reach Accounts but not app pages", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{portal_admin: true}))

      assert rendered_module(conn, "accounts,home", "&admin=true") == HfgPortalWeb.Accounts.Home.HomeLive
      assert rendered_module(conn, "budget,dashboard", "&admin=true") == HfgPortalWeb.Home.HomeLive
      assert rendered_module(conn, "dev_tools,input_gallery", "&admin=true") == HfgPortalWeb.Home.HomeLive
    end

    test "toggling admin mode navigates with admin=true and back", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{portal_admin: true}))
      {:ok, view, _} = live(conn, "/?page=home")

      assert {:error, {:live_redirect, %{to: to}}} = render_click(view, "toggle_admin_mode")
      assert to =~ "admin=true"
      assert to =~ "page=home"

      {:ok, view, _} = live(conn, "/?page=home&admin=true")
      assert {:error, {:live_redirect, %{to: to}}} = render_click(view, "toggle_admin_mode")
      refute to =~ "admin"
    end
  end

  describe "live role changes" do
    test "losing access to the open page navigates away from it", %{conn: conn} do
      user = user_fixture()
      budget_role(user, "Admin")
      conn = log_in(conn, user)
      {view, child} = open_page(conn, "budget,manage,accounts")
      assert child.module == HfgPortalWeb.Budget.Accounts.AccountsLive

      user_role = Budget.UserRoles.get(user.id, :user)
      {:ok, _} = Budget.UserRoles.create_or_update(user_role, %{role: "View"})

      {path, _flash} = assert_redirect(view)
      assert path =~ "page=budget,manage,accounts"
      # the page it lands on no longer renders it
      assert rendered_module(conn, "budget,manage,accounts") == HfgPortalWeb.Home.HomeLive
    end

    test "a new role shows the app without a reload", %{conn: conn} do
      user = user_fixture()
      {:ok, view, _} = conn |> log_in(user) |> live("/")
      refute has_element?(view, "a[phx-value-link='homm_saves']")

      homm_role(user, "Edit")
      assert has_element?(view, "a[phx-value-link='homm_saves']")
    end

    test "another user's role change does not touch this sidebar", %{conn: conn} do
      user = user_fixture()
      budget_role(user, "Admin")
      {view, _child} = conn |> log_in(user) |> open_page("budget,manage,accounts")

      budget_role(user_fixture(), "View")
      refute_redirected(view)
      assert find_live_child(view, "root").module == HfgPortalWeb.Budget.Accounts.AccountsLive
    end
  end

  defp refute_redirected(view) do
    %{proxy: {ref, topic, _}} = view
    refute_receive {^ref, {:redirect, ^topic, _}}, 100
  end

  describe "user settings" do
    setup %{conn: conn} do
      user = user_fixture(%{first_name: "Old", last_name: "Name"})
      {:ok, view, _} = conn |> log_in(user) |> live("/")
      render_click(view, "edit_user_settings")
      %{user: user, view: view}
    end

    test "opens a modal with the user's name fields and a JWT", %{view: view, user: user} do
      html = view |> element("#user_settings") |> render()
      assert html =~ "Change User Settings"
      assert html =~ user.username
      assert has_element?(view, "#user_settings input[name='user[first_name]']")
      # no access fields are offered
      refute has_element?(view, "#user_settings input[name='user[portal_admin]']")
      refute has_element?(view, "#user_settings input[name='user[username]']")
    end

    test "validate shows password errors", %{view: view} do
      html =
        view
        |> element("#user_settings form")
        |> render_change(%{"user" => %{"password" => "short", "password_confirm" => "short"}})

      assert html =~ "should be at least 12 character"
    end

    test "mismatched passwords are rejected and not saved", %{view: view, user: user} do
      view
      |> element("#user_settings form")
      |> render_submit(%{"user" => %{"password" => "a long new password", "password_confirm" => "something else!"}})

      assert has_element?(view, "#user_settings")
      assert render(view) =~ "Passwords do not match"
      assert Accounts.get(user.id).hashed_password == user.hashed_password
    end

    test "saving the name updates the user and the sidebar, then closes", %{view: view, user: user} do
      view
      |> element("#user_settings form")
      |> render_submit(%{"user" => %{"first_name" => "New", "last_name" => "Person"}})

      refute has_element?(view, "#user_settings")
      assert %{first_name: "New", last_name: "Person"} = Accounts.get(user.id)
      assert render(view) =~ "Person"
    end

    test "a new password can be used to sign in", %{view: view, user: user} do
      view
      |> element("#user_settings form")
      |> render_submit(%{"user" => %{"password" => "brand new password", "password_confirm" => "brand new password"}})

      assert Accounts.get_user_by_username_and_password(user.username, "brand new password")
    end

    test "crafted params cannot change access flags or the username", %{view: view, user: user} do
      view
      |> element("#user_settings form")
      |> render_submit(%{
        "user" => %{
          "first_name"   => "Mallory",
          "username"     => "admin",
          "portal_admin" => "true",
          "dev_admin"    => "true",
          "test_user"    => "true",
          "generic_user" => "true",
          "active"       => "false",
          "end_date"     => "2000-01-01"
        }
      })

      saved = Accounts.get(user.id)
      assert saved.first_name == "Mallory"
      assert saved.username == user.username
      refute saved.portal_admin
      refute saved.dev_admin
      refute saved.test_user
      refute saved.generic_user
      assert saved.active
      assert saved.end_date == nil
    end

    test "cancel closes the modal", %{view: view} do
      render_click(view, "cancel")
      refute has_element?(view, "#user_settings")
    end
  end
end
