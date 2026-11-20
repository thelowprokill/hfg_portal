defmodule WifeTime.WifeTimesTest do
  use WifeTime.DataCase

  alias WifeTime.WifeTimes
  alias WifeTime.WifeTimes.WifeTime, as: Entry
  alias HfgPortal.Helpers.{Search, Sort}

  defp entry(attrs) do
    {:ok, e} = WifeTimes.new() |> WifeTimes.create_or_update(Enum.into(attrs, %{happened: true}))
    e
  end

  describe "get_max_date/0" do
    test "is today when there are no entries" do
      assert WifeTimes.get_max_date() == Date.utc_today()
    end

    test "is the latest entry date, even one in the future" do
      entry(%{entry_date: ~D[2026-01-05]})
      entry(%{entry_date: ~D[2099-12-31]})
      entry(%{entry_date: ~D[2026-03-01]})
      assert WifeTimes.get_max_date() == ~D[2099-12-31]
    end
  end

  describe "create_or_update/2" do
    test "stores the entry with its creator and broadcasts it" do
      user = user_fixture()
      WifeTimes.subscribe()

      e = entry(%{entry_date: ~D[2026-02-01], menstration: true, comment: "hi", created_by_id: user.id})
      assert_receive {[:wife_time, :created], %Entry{id: id}}
      assert id == e.id
      assert %Entry{menstration: true, comment: "hi", happened: true} = WifeTimes.get(e.id)

      {:ok, _} = WifeTimes.create_or_update(e, %{happened: false, updated_by_id: user.id})
      assert_receive {[:wife_time, :updated], %Entry{happened: false}}
    end

    test "casts dates from strings and ignores unknown attrs" do
      e = entry(%{entry_date: "2026-02-03", bogus: 1})
      assert e.entry_date == ~D[2026-02-03]
    end

    test "rejects an unknown user" do
      assert_raise Ecto.ConstraintError, fn -> entry(%{entry_date: ~D[2026-01-01], created_by_id: -1}) end
    end
  end

  describe "list/1" do
    setup do
      user = user_fixture(%{first_name: "Pat"})
      a = entry(%{entry_date: ~D[2026-01-01], comment: "zz new year", created_by_id: user.id})
      b = entry(%{entry_date: ~D[2026-01-03], comment: "aa later"})
      c = entry(%{entry_date: ~D[2026-01-02], comment: "mm Middle"})
      %{user: user, a: a, b: b, c: c}
    end

    test "newest entry date first", %{a: a, b: b, c: c} do
      assert Enum.map(WifeTimes.list(%{}), & &1.id) == [b.id, c.id, a.id]
    end

    test "pages are consecutive slices of that order", %{a: a, b: b, c: c} do
      assert Enum.map(WifeTimes.list(%{page: 0, per_page: 2}), & &1.id) == [b.id, c.id]
      assert Enum.map(WifeTimes.list(%{page: 1, per_page: 2}), & &1.id) == [a.id]
      assert WifeTimes.list(%{page: 2, per_page: 2}) == []
    end

    test "search by comment substring (case sensitive)", %{c: c} do
      assert [c.id] == WifeTimes.list(%{search_stack: [%Search{field: :comment, val: "Mid"}]}) |> Enum.map(& &1.id)
      assert WifeTimes.list(%{search_stack: [%Search{field: :comment, val: "mid"}]}) == []
    end

    test "sort_stack takes precedence over the default date order", %{a: a, b: b, c: c} do
      sorted = WifeTimes.list(%{sort_stack: [%Sort{field: :comment, order: :asc}]})
      assert Enum.map(sorted, & &1.id) == [b.id, c.id, a.id]
      sorted = WifeTimes.list(%{sort_stack: [%Sort{field: :comment, order: :desc}]})
      assert Enum.map(sorted, & &1.id) == [a.id, c.id, b.id]
    end

    test "preloads the creator", %{user: user, a: a} do
      [loaded] = WifeTimes.list(%{preload: [:created_by, :updated_by]}) |> Enum.filter(&(&1.id == a.id))
      assert loaded.created_by.id == user.id
      assert loaded.created_by.first_name == "Pat"
      assert loaded.updated_by == nil
    end

    test "ignores the user_id the LiveView passes: entries are shared", %{user: user} do
      assert length(WifeTimes.list(%{user_id: user.id})) == 3
    end
  end

  test "delete/1 by id removes and broadcasts" do
    e = entry(%{entry_date: ~D[2026-01-01]})
    WifeTimes.subscribe(e.id)
    assert {:ok, _} = WifeTimes.delete(e.id)
    assert_receive {[:wife_time, :deleted], %Entry{}}
    assert WifeTimes.get(e.id) == nil
  end
end
