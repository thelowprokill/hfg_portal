defmodule HfgPortalWeb.HommSaves.LiveTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortal.AccountsFixtures
  import HfgPortalWeb.LiveHelpers

  alias HommSaves.{SaveFiles, UserRoles}

  @home HfgPortalWeb.Home.HomeLive
  @files HfgPortalWeb.HommSaves.Files.FilesLive
  @users HfgPortalWeb.HommSaves.Users.UsersLive

  describe "access" do
    for {role, saves, users} <- [{nil, false, false}, {"None", false, false}, {"Edit", true, false}, {"Admin", true, true}] do
      test "#{role || "no"} role", %{conn: conn} do
        user = user_fixture()
        if unquote(role), do: homm_role(user, unquote(role))
        conn = log_in(conn, user)

        assert rendered_module(conn, "homm_saves,home") == if(unquote(saves), do: @files, else: @home)
        assert rendered_module(conn, "homm_saves,users") == if(unquote(users), do: @users, else: @home)
      end
    end

    test "dev admin in admin mode reaches both", %{conn: conn} do
      conn = log_in(conn, user_fixture(%{dev_admin: true}))
      assert rendered_module(conn, "homm_saves,home", "&admin=true") == @files
      assert rendered_module(conn, "homm_saves,users", "&admin=true") == @users
      assert rendered_module(conn, "homm_saves,users") == @home
    end
  end

  describe "saves page" do
    @describetag :tmp_dir

    setup %{conn: conn, tmp_dir: tmp_dir} do
      previous = System.get_env("HOMM_SAVES_DIR")
      System.put_env("HOMM_SAVES_DIR", tmp_dir)
      on_exit(fn -> if previous, do: System.put_env("HOMM_SAVES_DIR", previous), else: System.delete_env("HOMM_SAVES_DIR") end)

      user = user_fixture()
      homm_role(user, "Edit")
      %{conn: log_in(conn, user)}
    end

    defp upsert!(path, section \\ "saves", machine \\ "pc1") do
      {:ok, f} = SaveFiles.upsert(section, path, machine)
      f
    end

    defp page_of(conn), do: conn |> open_page("homm_saves,home") |> elem(1)

    defp folder_open?(page, section, path),
      do: has_element?(page, "details[open] > summary[phx-value-section='#{section}'][phx-value-path='#{path}']")

    defp folder_shown?(page, section, path),
      do: has_element?(page, "summary[phx-value-section='#{section}'][phx-value-path='#{path}']")

    test "empty sections say so", %{conn: conn} do
      html = render(page_of(conn))
      assert html =~ "Save Games"
      assert html =~ "RMG Templates"
      assert html =~ "Nothing uploaded yet."
      assert html =~ "never"
    end

    test "files are shown as a folder tree per section", %{conn: conn} do
      upsert!("campaign/day1.GM1")
      upsert!("campaign/sub/day2.GM1")
      upsert!("loose.GM1")
      upsert!("Jebus.h3t", "templates")

      page = page_of(conn)
      html = render(page)

      assert folder_shown?(page, "saves", "campaign")
      assert folder_shown?(page, "saves", "campaign/sub")
      assert html =~ "day1.GM1"
      assert html =~ "day2.GM1"
      assert html =~ "loose.GM1"
      assert has_element?(page, "[phx-click='delete'][phx-value-section='templates'][phx-value-path='Jebus.h3t']")
      refute html =~ "Nothing uploaded yet."
    end

    test "load more fetches the next 50 of a section only", %{conn: conn} do
      oldest = upsert!("old/first.GM1")
      for i <- 1..50, do: upsert!("new/#{i}.GM1")
      upsert!("t.h3t", "templates")

      page = page_of(conn)
      refute has_element?(page, "[phx-value-path='#{oldest.path}']")
      assert has_element?(page, "#load_more_saves")
      refute has_element?(page, "#load_more_templates")

      render_click(page, "load_more", %{"section" => "saves"})
      assert has_element?(page, "[phx-click='delete'][phx-value-path='#{oldest.path}']")
      refute has_element?(page, "#load_more_saves")
      assert has_element?(page, "[phx-value-path='new/50.GM1']")
    end

    test "a collapsed folder stays collapsed across load more and live updates", %{conn: conn} do
      for i <- 1..51, do: upsert!("big/#{i}.GM1")
      upsert!("other/x.GM1")

      page = page_of(conn)
      assert folder_open?(page, "saves", "big")

      page |> element("summary[phx-value-path='big']") |> render_click()
      refute folder_open?(page, "saves", "big")
      assert folder_open?(page, "saves", "other")

      render_click(page, "load_more", %{"section" => "saves"})
      assert folder_shown?(page, "saves", "big")
      refute folder_open?(page, "saves", "big")

      upsert!("big/52.GM1")
      refute folder_open?(page, "saves", "big")

      # toggling again reopens it
      page |> element("summary[phx-value-path='big']") |> render_click()
      assert folder_open?(page, "saves", "big")
    end

    test "collapsing is per section", %{conn: conn} do
      upsert!("shared/a.GM1")
      upsert!("shared/b.h3t", "templates")
      page = page_of(conn)

      page |> element("summary[phx-value-section='saves'][phx-value-path='shared']") |> render_click()
      refute folder_open?(page, "saves", "shared")
      assert folder_open?(page, "templates", "shared")
    end

    test "an upsert broadcast adds or changes just that file", %{conn: conn} do
      upsert!("keep.GM1")
      page = page_of(conn)

      upsert!("live/new.GM1", "saves", "laptop")
      html = render(page)
      assert html =~ "new.GM1"
      assert html =~ "laptop"
      assert html =~ "keep.GM1"

      upsert!("keep.GM1", "saves", "desktop")
      assert page |> element("li", "keep.GM1") |> render() =~ "desktop"
    end

    test "an upsert in another section does not show in this one", %{conn: conn} do
      page = page_of(conn)
      upsert!("tpl.h3t", "templates")

      assert render(page) =~ "tpl.h3t"
      assert has_element?(page, "[phx-value-section='templates'][phx-value-path='tpl.h3t']")
      refute has_element?(page, "[phx-value-section='saves'][phx-value-path='tpl.h3t']")
    end

    test "deleting a file removes only it", %{conn: conn} do
      upsert!("dir/a.GM1")
      upsert!("dir/b.GM1")
      page = page_of(conn)

      render_click(page, "delete", %{"section" => "saves", "path" => "dir/a.GM1"})
      refute has_element?(page, "[phx-value-path='dir/a.GM1']")
      assert has_element?(page, "[phx-value-path='dir/b.GM1']")
      assert [%{path: "dir/b.GM1"}] = SaveFiles.list("saves", 10)
    end

    test "deleting a folder removes everything under it, not look-alike siblings", %{conn: conn} do
      upsert!("game_1/a.GM1")
      upsert!("game_1/sub/b.GM1")
      upsert!("gameX1/c.GM1")
      page = page_of(conn)

      render_click(page, "delete", %{"section" => "saves", "path" => "game_1"})

      refute folder_shown?(page, "saves", "game_1")
      assert folder_shown?(page, "saves", "gameX1")
      assert [%{path: "gameX1/c.GM1"}] = SaveFiles.list("saves", 10)
    end

    test "deletes made elsewhere show live", %{conn: conn} do
      upsert!("gone/a.GM1")
      upsert!("stay.GM1")
      page = page_of(conn)

      {:ok, 1} = SaveFiles.delete("saves", "gone")
      refute folder_shown?(page, "saves", "gone")
      assert render(page) =~ "stay.GM1"
    end

    test "a path escaping the section is refused", %{conn: conn} do
      upsert!("a.GM1")
      page = page_of(conn)

      render_click(page, "delete", %{"section" => "saves", "path" => "../templates"})
      render_click(page, "delete", %{"section" => "etc", "path" => "a.GM1"})

      assert [%{path: "a.GM1"}] = SaveFiles.list("saves", 10)
      assert has_element?(page, "[phx-value-path='a.GM1']")
    end
  end

  describe "users page" do
    setup %{conn: conn} do
      admin = user_fixture()
      homm_role(admin, "Admin")
      %{conn: log_in(conn, admin), admin: admin}
    end

    test "grant a role through the modal", %{conn: conn, admin: admin} do
      other = user_fixture(%{first_name: "Gelu"})
      {_view, page} = open_page(conn, "homm_saves,users")

      assert has_element?(page, "[phx-click='edit'][phx-value-id='#{other.id}']")
      refute has_element?(page, "[phx-click='edit'][phx-value-id='#{admin.id}']")

      render_click(page, "edit", %{"id" => "#{other.id}"})
      page |> element("#modal form") |> render_submit(%{"user_role" => %{"role" => "Edit", "user_id" => "#{other.id}"}})

      assert UserRoles.get(other.id, :user).role == "Edit"
      assert page |> element("tr", "Gelu") |> render() =~ "Edit"
    end

    test "role changes elsewhere update the row live", %{conn: conn} do
      other = user_fixture(%{first_name: "Gelu"})
      {_view, page} = open_page(conn, "homm_saves,users")

      homm_role(other, "Admin")
      assert page |> element("tr", "Gelu") |> render() =~ "Admin"
    end

    test "sort by first name", %{conn: conn} do
      user_fixture(%{first_name: "Aaron"})
      user_fixture(%{first_name: "Zed"})
      {_view, page} = open_page(conn, "homm_saves,users")

      render_click(page, "sort", %{"field" => "first_name"})
      html = render(page)
      assert :binary.match(html, "Aaron") < :binary.match(html, "Zed")

      render_click(page, "sort", %{"field" => "first_name"})
      html = render(page)
      assert :binary.match(html, "Zed") < :binary.match(html, "Aaron")
    end
  end
end
