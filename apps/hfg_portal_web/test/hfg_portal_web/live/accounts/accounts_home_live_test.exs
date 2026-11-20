defmodule HfgPortalWeb.Accounts.Home.HomeLiveTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortal.AccountsFixtures
  import HfgPortalWeb.LiveHelpers

  alias HfgPortal.Accounts

  @page "accounts,home"
  @admin "&admin=true"

  describe "access" do
    test "normal users never get the page", %{conn: conn} do
      conn = log_in(conn, user_fixture())
      # with &admin=true it crashes instead, see SidebarLiveTest "a crafted ?admin=true"
      assert rendered_module(conn, @page) == HfgPortalWeb.Home.HomeLive
    end

    test "admins need admin mode", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{portal_admin: true}))
      assert rendered_module(conn, @page) == HfgPortalWeb.Home.HomeLive
      assert rendered_module(conn, @page, @admin) == HfgPortalWeb.Accounts.Home.HomeLive
    end

    test "dev admins in admin mode get it too", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{dev_admin: true}))
      assert rendered_module(conn, @page, @admin) == HfgPortalWeb.Accounts.Home.HomeLive
    end
  end

  describe "as a portal admin" do
    setup %{conn: conn} do
      admin = user_fixture(%{portal_admin: true, username: "zz_admin"})
      {view, page} = conn |> log_in(admin) |> open_page(@page, @admin)
      %{admin: admin, view: view, page: page}
    end

    test "lists users", %{page: page, admin: admin} do
      assert render(page) =~ admin.username
    end

    test "load more fetches the next page of 30", %{conn: conn, admin: admin} do
      users = for i <- 1..35, do: user_fixture(%{username: "bulk#{String.pad_leading("#{i}", 2, "0")}"})
      {_view, page} = conn |> log_in(admin) |> open_page(@page, @admin <> "&sort=asc|username")

      html = render(page)
      assert html =~ "bulk30"
      refute html =~ "bulk31"

      html = render_click(page, "load_more")
      for u <- users, do: assert(html =~ u.username)
      assert html =~ admin.username
    end

    test "search filters by username", %{page: page} do
      user_fixture(%{username: "findme_alpha"})
      user_fixture(%{username: "other_beta"})

      render_click(page, "search", %{"field" => "username"})
      html = render_change(page, "search", %{"search" => %{"field" => "username", "val" => "findme"}})

      assert html =~ "findme_alpha"
      refute html =~ "other_beta"

      html = render_click(page, "reset_filters", %{"field" => "username"})
      assert html =~ "other_beta"
    end

    test "searching the ID column filters instead of crashing", %{page: page, admin: admin} do
      other = user_fixture()

      render_click(page, "search", %{"field" => "id"})
      html = render_change(page, "search", %{"search" => %{"field" => "id", "val" => "#{other.id}"}})

      assert html =~ other.username
      refute html =~ admin.username
    end

    test "sort toggles ascending and descending", %{page: page} do
      user_fixture(%{username: "aaa_first"})

      render_click(page, "sort", %{"field" => "username"})
      html = render(page)
      assert index(html, "aaa_first") < index(html, "zz_admin")

      render_click(page, "sort", %{"field" => "username"})
      html = render(page)
      assert index(html, "zz_admin") < index(html, "aaa_first")
    end

    test "new user: validation errors then save", %{page: page} do
      render_click(page, "add_new")
      assert has_element?(page, "#accounts_modal")

      html =
        page
        |> element("#accounts_modal form")
        |> render_change(%{"user" => %{"username" => "", "password" => "short"}})

      assert html =~ "can&#39;t be blank"
      assert html =~ "should be at least 12 character"

      page
      |> element("#accounts_modal form")
      |> render_submit(%{
        "user" => %{
          "username" => "brand_new",
          "first_name" => "Brand",
          "password" => "a good long password",
          "password_confirm" => "a good long password",
          "active" => "true"
        }
      })

      refute has_element?(page, "#accounts_modal")
      assert Accounts.get_user_by_username_and_password("brand_new", "a good long password")
      assert render(page) =~ "brand_new"
    end

    test "duplicate usernames are refused", %{page: page, admin: admin} do
      render_click(page, "add_new")

      html =
        page
        |> element("#accounts_modal form")
        |> render_submit(%{
          "user" => %{
            "username" => admin.username,
            "password" => "a good long password",
            "password_confirm" => "a good long password"
          }
        })

      assert html =~ "has already been taken"
      assert has_element?(page, "#accounts_modal")
    end

    test "edit changes a user and keeps the password", %{page: page} do
      user = user_fixture(%{first_name: "Before"})

      render_click(page, "edit", %{"id" => "#{user.id}"})
      assert page |> element("#accounts_modal") |> render() =~ "Edit"

      page
      |> element("#accounts_modal form")
      |> render_submit(%{"user" => %{"first_name" => "After", "portal_admin" => "true"}})

      saved = Accounts.get(user.id)
      assert saved.first_name == "After"
      assert saved.portal_admin
      assert Accounts.get_user_by_username_and_password(user.username, valid_user_password())
    end

    test "delete removes the user", %{page: page} do
      user = user_fixture(%{username: "to_delete"})
      assert render(page) =~ "to_delete"

      render_click(page, "delete", %{"id" => "#{user.id}"})

      refute Accounts.get(user.id)
      refute render(page) =~ "to_delete"
    end

    test "deleting a user that has an app role does not crash the page", %{page: page} do
      user = user_fixture()
      budget_role(user, "View")

      render_click(page, "delete", %{"id" => "#{user.id}"})
      assert render(page)
    end

    test "activate / deactivate toggle each flag", %{page: page} do
      user = user_fixture()

      render_click(page, "deactivate", %{"id" => "#{user.id}", "key" => "active"})
      refute Accounts.get(user.id).active

      render_click(page, "activate", %{"id" => "#{user.id}", "key" => "dev_admin"})
      assert Accounts.get(user.id).dev_admin

      render_click(page, "deactivate", %{"id" => "#{user.id}", "key" => "dev_admin"})
      refute Accounts.get(user.id).dev_admin
    end

    test "users created, changed and deleted elsewhere show up live", %{page: page} do
      user = user_fixture(%{username: "live_one", first_name: "Firstname"})
      assert render(page) =~ "live_one"

      {:ok, _} = Accounts.create_or_update(user, %{first_name: "Renamed"})
      assert render(page) =~ "Renamed"

      {:ok, _} = Accounts.delete(user.id)
      refute render(page) =~ "live_one"
    end
  end

  defp index(html, text) do
    {i, _} = :binary.match(html, text)
    i
  end
end
