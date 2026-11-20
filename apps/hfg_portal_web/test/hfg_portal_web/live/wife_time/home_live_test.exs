defmodule HfgPortalWeb.WifeTime.HomeLiveTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortalWeb.LiveFixtures2

  alias WifeTime.{WifeTimes, UserRoles}

  @page "wife_time,home"

  defp entry_fixture(attrs) do
    {:ok, entry} = WifeTimes.create_or_update(WifeTimes.new(), Enum.into(attrs, %{happened: false, menstration: false}))
    entry
  end

  defp rows(page), do: count(page, ~s(tbody tr))

  setup %{conn: conn} do
    user = user_with_role(UserRoles, "Edit")
    %{conn: log_in_user(conn, user), user: user}
  end

  describe "authorization" do
    test "an Edit user opens the page", %{conn: conn} do
      assert page_module(conn, @page) == HfgPortalWeb.WifeTime.Home.HomeLive
    end

    test "None or no role gets the portal home", %{conn: conn} do
      for user <- [user_with_role(UserRoles, "None"), HfgPortal.AccountsFixtures.user_fixture()] do
        assert page_module(log_in_user(conn, user), @page) == HfgPortalWeb.Home.HomeLive
      end
    end
  end

  describe "entries" do
    test "listed newest first with check/ban icons and comments", %{conn: conn} do
      entry_fixture(%{entry_date: ~D[2026-01-01], comment: "first"})
      entry_fixture(%{entry_date: ~D[2026-01-03], comment: "third", happened: true})
      entry_fixture(%{entry_date: ~D[2026-01-02], comment: "second"})

      {_view, page} = open_page(conn, @page)
      assert dates(page) == ~w(2026-01-03 2026-01-02 2026-01-01)
      assert render(page) =~ "third"
    end

    test "new entry defaults to the day after the latest one and saves", %{conn: conn, user: user} do
      entry_fixture(%{entry_date: ~D[2026-02-10]})
      {_view, page} = open_page(conn, @page)

      render_click(page, "add_new", %{})
      assert has_element?(page, ~s(#wife_time input[name="wife_time[entry_date]"][value="2026-02-11"]))

      page
      |> form("#wife_time form", %{"wife_time" => %{"happened" => "true", "comment" => "nice"}})
      |> render_submit()

      refute has_element?(page, "#wife_time")
      entry = WifeTimes.list(%{}) |> Enum.find(&(&1.entry_date == ~D[2026-02-11]))
      assert %{happened: true, menstration: false, comment: "nice", created_by_id: id, updated_by_id: id} = entry
      assert id == user.id
      assert dates(page) |> hd() == "2026-02-11"
    end

    test "an invalid date shows an error and saves nothing", %{conn: conn} do
      {_view, page} = open_page(conn, @page)
      render_click(page, "add_new", %{})

      html = page |> form("#wife_time form", %{"wife_time" => %{"entry_date" => "not a date"}}) |> render_change()
      assert html =~ "is invalid"
      page |> form("#wife_time form", %{"wife_time" => %{"entry_date" => "not a date"}}) |> render_submit()
      assert WifeTimes.list(%{}) == []
    end

    test "edit and delete", %{conn: conn} do
      entry = entry_fixture(%{entry_date: ~D[2026-03-01], comment: "old"})
      {_view, page} = open_page(conn, @page)

      render_click(page, "edit", %{"id" => "#{entry.id}"})
      page |> form("#wife_time form", %{"wife_time" => %{"comment" => "edited", "menstration" => "true"}}) |> render_submit()
      assert %{comment: "edited", menstration: true} = WifeTimes.get(entry.id)
      assert render(page) =~ "edited"

      render_click(page, "delete", %{"id" => "#{entry.id}"})
      assert WifeTimes.get(entry.id) == nil
      assert rows(page) == 0
    end

    test "search by comment", %{conn: conn} do
      entry_fixture(%{entry_date: ~D[2026-01-01], comment: "beach trip"})
      entry_fixture(%{entry_date: ~D[2026-01-02], comment: "at home"})
      {_view, page} = open_page(conn, @page)

      render_click(page, "search", %{"field" => "comment"})
      render_change(page, "search", %{"search" => %{"field" => "comment", "val" => "beach"}})
      assert dates(page) == ["2026-01-01"]
    end

    test "shows 50 entries and loads more", %{conn: conn} do
      for d <- 1..53, do: entry_fixture(%{entry_date: Date.add(~D[2025-01-01], d)})
      {_view, page} = open_page(conn, @page)

      assert rows(page) == 50
      render_click(page, "load_more", %{})
      assert rows(page) == 53
    end

    test "changes made elsewhere show up live", %{conn: conn} do
      entry = entry_fixture(%{entry_date: ~D[2026-04-01], comment: "before"})
      {_view, page} = open_page(conn, @page)

      {:ok, _} = WifeTimes.create_or_update(entry, %{comment: "after"})
      assert render(page) =~ "after"

      other = entry_fixture(%{entry_date: ~D[2026-04-02], comment: "added"})
      assert render(page) =~ "added"

      WifeTimes.delete(other)
      refute render(page) =~ "added"
    end
  end

  defp dates(page) do
    page
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.find("tbody tr td:first-child")
    |> Enum.map(&String.trim(Floki.text(&1)))
  end
end
