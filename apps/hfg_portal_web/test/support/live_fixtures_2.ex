defmodule HfgPortalWeb.LiveFixtures2 do
  @moduledoc """
  Helpers for LiveView tests of the sidebar-hosted app pages (car maintenance, loan repayment,
  timekeeping, wife time, home, dev tools).

  Every page lives inside `Layout.SidebarLive` at `/?page=<app>,<page>` and is rendered as a
  nested LiveView with id "root". The sidebar only renders a page the user is authorized for and
  falls back to `HfgPortalWeb.Home.HomeLive` otherwise.
  """

  import Phoenix.ConnTest, only: [get: 2]
  import Phoenix.LiveViewTest

  @endpoint HfgPortalWeb.Endpoint

  @doc "A user with `role` in the app whose user_roles module is `user_roles` (e.g. CarMaintenance.UserRoles)."
  def user_with_role(user_roles, role, attrs \\ %{}) do
    user = HfgPortal.AccountsFixtures.user_fixture(attrs)
    set_role(user_roles, user, role)
    user
  end

  def set_role(user_roles, user, role) do
    item = user_roles.get(user.id, :user) || user_roles.new()
    {:ok, user_role} = user_roles.create_or_update(item, %{user_id: user.id, role: role})
    user_role
  end

  @doc "Opens `/?page=...` (with `admin: true` for admin mode) and returns `{sidebar_view, page_view}`."
  def open_page(conn, page, opts \\ []) do
    query = URI.encode_query([page: page] ++ if(opts[:admin], do: [admin: "true"], else: []))
    {:ok, view, _html} = live(conn, "/?" <> query)
    {view, find_live_child(view, "root")}
  end

  @doc "The LiveView module the sidebar rendered for `page`."
  def page_module(conn, page, opts \\ []) do
    {_view, child} = open_page(conn, page, opts)
    child.module
  end

  @doc "Number of elements matching `selector` in the view's current render."
  def count(view, selector) do
    view |> render() |> Floki.parse_fragment!() |> Floki.find(selector) |> length()
  end
end

defmodule HfgPortalWeb.LiveFixtures2.UsersPageTests do
  @moduledoc """
  The four apps' Users pages (car_maintenance, loan_repayment, timekeeping, wife_time) are the
  same code. `use` this in a ConnCase test module to get the shared tests:

      use HfgPortalWeb.LiveFixtures2.UsersPageTests,
        app: "car_maintenance", user_roles: CarMaintenance.UserRoles,
        module: HfgPortalWeb.CarMaintenance.Users.UsersLive, admin_role: nil

  `admin_role` is the app role (if any) that opens the Users page without dev admin.
  """

  defmacro __using__(opts) do
    quote do
      import Phoenix.LiveViewTest
      import HfgPortalWeb.LiveFixtures2

      @app        unquote(opts[:app])
      @user_roles unquote(opts[:user_roles])
      @module     unquote(opts[:module])
      @admin_role unquote(opts[:admin_role])
      @page       "#{@app},users"

      defp dev_admin_conn(conn) do
        dev = HfgPortal.AccountsFixtures.user_fixture(%{dev_admin: true, first_name: "Dev"})
        {log_in_user(conn, dev), dev}
      end

      describe "users page authorization" do
        test "an Edit user can't open it", %{conn: conn} do
          user = user_with_role(@user_roles, "Edit")
          conn = log_in_user(conn, user)
          assert page_module(conn, @page) == HfgPortalWeb.Home.HomeLive
        end

        test "an Edit user adding ?admin=true still can't open it", %{conn: conn} do
          conn = log_in_user(conn, user_with_role(@user_roles, "Edit"))
          assert page_module(conn, @page, admin: true) == HfgPortalWeb.Home.HomeLive
        end

        test "a user without a role can't open it", %{conn: conn} do
          conn = log_in_user(conn, HfgPortal.AccountsFixtures.user_fixture())
          assert page_module(conn, @page) == HfgPortalWeb.Home.HomeLive
        end

        test "a portal admin (not dev admin) can't open it, even in admin mode", %{conn: conn} do
          conn = log_in_user(conn, HfgPortal.AccountsFixtures.user_fixture(%{portal_admin: true}))
          assert page_module(conn, @page, admin: true) == HfgPortalWeb.Home.HomeLive
        end

        test "a dev admin needs admin mode", %{conn: conn} do
          {conn, _dev} = dev_admin_conn(conn)
          assert page_module(conn, @page) == HfgPortalWeb.Home.HomeLive
          assert page_module(conn, @page, admin: true) == @module
        end

        if @admin_role do
          test "the #{@admin_role} role opens it without admin mode", %{conn: conn} do
            conn = log_in_user(conn, user_with_role(@user_roles, @admin_role))
            assert page_module(conn, @page) == @module
          end

          test "without admin mode an app admin can't edit their own role", %{conn: conn} do
            me = user_with_role(@user_roles, @admin_role)
            other = HfgPortal.AccountsFixtures.user_fixture()
            {_view, page} = open_page(log_in_user(conn, me), @page)

            refute has_element?(page, ~s(button[phx-click="edit"][phx-value-id="#{me.id}"]))
            assert has_element?(page, ~s(button[phx-click="edit"][phx-value-id="#{other.id}"]))
          end
        end
      end

      describe "users page" do
        setup %{conn: conn} do
          {conn, dev} = dev_admin_conn(conn)
          %{conn: conn, dev: dev}
        end

        test "lists users with their role", %{conn: conn} do
          editor = user_with_role(@user_roles, "Edit", %{first_name: "Edna"})
          nobody = HfgPortal.AccountsFixtures.user_fixture(%{first_name: "Norm"})
          {_view, page} = open_page(conn, @page, admin: true)

          html = render(page)
          assert html =~ editor.username
          assert html =~ nobody.username
          assert row_text(page, editor) =~ "Edit"
          assert row_text(page, nobody) =~ "None"
          # a dev admin in admin mode can edit everyone, themselves included
          assert has_element?(page, ~s(button[phx-click="edit"][phx-value-id="#{editor.id}"]))
        end

        test "edit modal gives a user without a role one, and the row updates live", %{conn: conn} do
          user = HfgPortal.AccountsFixtures.user_fixture()
          {_view, page} = open_page(conn, @page, admin: true)

          render_click(page, "edit", %{"id" => "#{user.id}"})
          assert has_element?(page, "#modal")

          page |> form("#modal form", %{"user_role" => %{"role" => "Edit"}}) |> render_submit()

          assert @user_roles.get(user.id, :user).role == "Edit"
          refute has_element?(page, "#modal")
          assert row_text(page, user) =~ "Edit"
        end

        test "edit modal changes an existing role", %{conn: conn} do
          user = user_with_role(@user_roles, "Edit")
          {_view, page} = open_page(conn, @page, admin: true)

          render_click(page, "edit", %{"id" => "#{user.id}"})
          page |> form("#modal form", %{"user_role" => %{"role" => "None"}}) |> render_submit()

          assert @user_roles.get(user.id, :user).role == "None"
          assert row_text(page, user) =~ "None"
        end

        test "cancel closes the modal without saving", %{conn: conn} do
          user = HfgPortal.AccountsFixtures.user_fixture()
          {_view, page} = open_page(conn, @page, admin: true)

          render_click(page, "edit", %{"id" => "#{user.id}"})
          render_click(page, "cancel", %{})
          refute has_element?(page, "#modal")
          assert @user_roles.get(user.id, :user) == nil
        end

        test "a role changed elsewhere shows up live", %{conn: conn} do
          user = HfgPortal.AccountsFixtures.user_fixture()
          {_view, page} = open_page(conn, @page, admin: true)
          assert row_text(page, user) =~ "None"

          set_role(@user_roles, user, "Edit")
          assert row_text(page, user) =~ "Edit"
        end

        test "searching by username narrows the list", %{conn: conn} do
          a = HfgPortal.AccountsFixtures.user_fixture(%{username: "zebra_#{System.unique_integer([:positive])}"})
          b = HfgPortal.AccountsFixtures.user_fixture()
          {_view, page} = open_page(conn, @page, admin: true)

          render_click(page, "search", %{"field" => "username"})
          render_change(page, "search", %{"search" => %{"field" => "username", "val" => "zebra_"}})

          html = render(page)
          assert html =~ a.username
          refute html =~ b.username
        end

        test "filtering by role shows only that role", %{conn: conn} do
          editor = user_with_role(@user_roles, "Edit")
          nobody = HfgPortal.AccountsFixtures.user_fixture()
          {_view, page} = open_page(conn, @page, admin: true)

          render_click(page, "search", %{"field" => "role"})
          render_change(page, "search", %{"search" => %{"field" => "role", "val" => "Edit"}})

          html = render(page)
          assert html =~ editor.username
          refute html =~ nobody.username

          render_click(page, "reset_filters", %{})
          assert render(page) =~ nobody.username
        end

        test "sorting by username orders the rows", %{conn: conn} do
          for name <- ["aaa_sort", "zzz_sort"],
            do: HfgPortal.AccountsFixtures.user_fixture(%{username: "#{name}_#{System.unique_integer([:positive])}"})

          {_view, page} = open_page(conn, @page, admin: true)

          render_click(page, "sort", %{"field" => "username"})
          names = usernames(page)
          assert names == Enum.sort(names)

          render_click(page, "sort", %{"field" => "username"})
          names = usernames(page)
          assert names == Enum.sort(names, :desc)
        end

        test "shows 30 users at a time and loads more", %{conn: conn} do
          for _ <- 1..35, do: HfgPortal.AccountsFixtures.user_fixture()
          {_view, page} = open_page(conn, @page, admin: true)

          assert count(page, "tbody tr") == 30
          render_click(page, "load_more", %{})
          # 35 + the dev admin
          assert count(page, "tbody tr") == 36
        end
      end

      defp row_text(page, user) do
        page
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("tbody tr")
        |> Enum.find(&(Floki.text(&1) =~ user.username))
        |> Floki.text()
      end

      defp usernames(page) do
        page
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("tbody tr td:first-child")
        |> Enum.map(&String.trim(Floki.text(&1)))
      end
    end
  end
end
