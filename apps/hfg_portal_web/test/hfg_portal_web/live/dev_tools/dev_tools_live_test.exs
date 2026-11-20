defmodule HfgPortalWeb.DevTools.DevToolsLiveTest do
  use HfgPortalWeb.ConnCase

  import HfgPortalWeb.LiveFixtures2
  import HfgPortal.AccountsFixtures

  alias HfgPortalWeb.DevTools

  @pages %{
    "dev_tools,expand,button_gallery" => DevTools.ButtonGallery.ButtonGalleryLive,
    "dev_tools,expand,icon_gallery"   => DevTools.IconGallery.IconGallery,
    "dev_tools,infinite_scroll"       => DevTools.InfiniteScroll.InfiniteScrollLive,
    "dev_tools,input_gallery"         => DevTools.InputGallery.InputGalleryLive,
  }

  test "a dev admin in admin mode gets every dev tool", %{conn: conn} do
    conn = log_in_user(conn, user_fixture(%{dev_admin: true}))

    for {page, module} <- @pages do
      assert page_module(conn, page, admin: true) == module, page
    end
  end

  test "a dev admin outside admin mode gets none", %{conn: conn} do
    conn = log_in_user(conn, user_fixture(%{dev_admin: true}))

    for {page, _} <- @pages do
      assert page_module(conn, page) == HfgPortalWeb.Home.HomeLive, page
    end
  end

  test "a portal admin, even in admin mode, gets none", %{conn: conn} do
    conn = log_in_user(conn, user_fixture(%{portal_admin: true}))

    for {page, _} <- @pages, admin <- [false, true] do
      assert page_module(conn, page, admin: admin) == HfgPortalWeb.Home.HomeLive, page
    end
  end

  test "a regular user gets none", %{conn: conn} do
    conn = log_in_user(conn, user_fixture())

    for {page, _} <- @pages do
      assert page_module(conn, page) == HfgPortalWeb.Home.HomeLive, page
    end
  end

  test "there is no Archive dev tool (the page was never built)", %{conn: conn} do
    conn = log_in_user(conn, user_fixture(%{dev_admin: true}))
    assert page_module(conn, "dev_tools,expand,archive", admin: true) == HfgPortalWeb.Home.HomeLive
  end
end
