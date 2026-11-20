# A throwaway schema exercising every DefaultCrud feature (active/archive flags, `order`, an
# archive table). Its tables are created inside each test's sandbox transaction, so they vanish
# on rollback.
defmodule HfgPortal.DefaultCrudTest.Item do
  use Ecto.Schema
  import Ecto.Changeset

  @schema_prefix "hfg_portal_test"
  schema "crud_test_items" do
    field :name,    :string
    field :order,   :integer
    field :active,  :boolean, default: true
    field :archive, :boolean, default: false
    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [:name, :order, :active, :archive])
    |> validate_required([:name])
  end
end

defmodule HfgPortal.DefaultCrudTest.ItemArchive do
  use Ecto.Schema
  import Ecto.Changeset

  @schema_prefix "hfg_portal_test"
  schema "crud_test_item_archives" do
    field :item_id, :integer
    field :name,    :string
    field :order,   :integer
    timestamps()
  end

  def changeset(row, attrs), do: cast(row, attrs, [:item_id, :name, :order])
end

defmodule HfgPortal.DefaultCrudTest.Items do
  use HfgPortal.Helpers.DefaultCrud,
    schema:  HfgPortal.DefaultCrudTest.Item,
    topic:   "test:items",
    updated: [:item, :updated],
    created: [:item, :created],
    deleted: [:item, :deleted],
    archive: HfgPortal.DefaultCrudTest.ItemArchive
end

defmodule HfgPortal.DefaultCrudTest do
  use HfgPortal.DataCase

  alias HfgPortal.DefaultCrudTest.{Item, ItemArchive, Items}
  alias HfgPortal.Helpers.{Search, Sort}

  setup do
    Repo.query!("""
    CREATE TABLE hfg_portal_test.crud_test_items (
      id bigserial PRIMARY KEY, name varchar(255), "order" integer,
      active boolean NOT NULL DEFAULT true, archive boolean NOT NULL DEFAULT false,
      inserted_at timestamp(0) NOT NULL, updated_at timestamp(0) NOT NULL)
    """)

    Repo.query!("""
    CREATE TABLE hfg_portal_test.crud_test_item_archives (
      id bigserial PRIMARY KEY, item_id bigint, name varchar(255), "order" integer,
      inserted_at timestamp(0) NOT NULL, updated_at timestamp(0) NOT NULL)
    """)

    :ok
  end

  defp item(attrs) do
    {:ok, i} = Items.new() |> Items.create_or_update(attrs)
    i
  end

  defp ids(items), do: Enum.map(items, & &1.id)

  describe "list/1" do
    setup do
      a = item(%{name: "apple",  order: 3})
      b = item(%{name: "banana", order: 1, active: false})
      c = item(%{name: "cherry", order: 2, archive: true})
      %{a: a, b: b, c: c}
    end

    test "without options returns everything", %{a: a, b: b, c: c} do
      assert Enum.sort(ids(Items.list())) == Enum.sort([a.id, b.id, c.id])
    end

    test "search_stack: substring match, blank matches all, unknown fields ignored, several AND together", %{a: a, b: b} do
      assert ids(Items.list(%{search_stack: [%Search{field: :name, val: "ana"}]})) == [b.id]
      assert length(Items.list(%{search_stack: [%Search{field: :name, val: ""}]})) == 3
      assert length(Items.list(%{search_stack: [%Search{field: :bogus, val: "x"}]})) == 3

      both = [%Search{field: :name, val: "a"}, %Search{field: :name, val: "pp"}]
      assert ids(Items.list(%{search_stack: both})) == [a.id]
    end

    test "search_stack on a timestamp keeps rows at or after it" do
      assert length(Items.list(%{search_stack: [%Search{field: :updated_at, val: ~N[2000-01-01 00:00:00]}]})) == 3
      assert Items.list(%{search_stack: [%Search{field: :updated_at, val: ~N[2999-01-01 00:00:00]}]}) == []
    end

    test "sort_stack: asc/desc, first sort wins, unknown fields ignored", %{a: a, b: b, c: c} do
      assert ids(Items.list(%{sort_stack: [%Sort{field: :order, order: :asc}]})) == [b.id, c.id, a.id]
      assert ids(Items.list(%{sort_stack: [%Sort{field: :name, order: :desc}]})) == [c.id, b.id, a.id]
      assert ids(Items.list(%{sort_stack: [%Sort{field: :bogus}, %Sort{field: :name}]})) == [a.id, b.id, c.id]

      d = item(%{name: "apple", order: 0})
      two = [%Sort{field: :name, order: :asc}, %Sort{field: :order, order: :asc}]
      assert ids(Items.list(%{sort_stack: two})) == [d.id, a.id, b.id, c.id]
    end

    test "zero-based pagination, numbers or strings", %{a: a, b: b, c: c} do
      sort = [%Sort{field: :name}]
      assert ids(Items.list(%{sort_stack: sort, page: 0, per_page: 2})) == [a.id, b.id]
      assert ids(Items.list(%{sort_stack: sort, page: 1, per_page: 2})) == [c.id]
      assert ids(Items.list(%{sort_stack: sort, page: "1", per_page: "2"})) == [c.id]
      assert Items.list(%{sort_stack: sort, page: 5, per_page: 2}) == []
      assert length(Items.list(%{sort_stack: sort, page: nil, per_page: 2})) == 3
    end

    test "active and archive flags filter, nil means either", %{a: a, b: b, c: c} do
      assert ids(Items.list(%{active: false})) == [b.id]
      assert Enum.sort(ids(Items.list(%{active: true}))) == Enum.sort([a.id, c.id])
      assert ids(Items.list(%{archive: true})) == [c.id]
      assert ids(Items.list(%{active: true, archive: false})) == [a.id]
      assert length(Items.list(%{active: nil, archive: nil})) == 3
    end
  end

  describe "create_or_update/2" do
    test "broadcasts created/updated to the topic and the item's own topic" do
      Items.subscribe()
      i = item(%{name: "one"})
      assert_receive {[:item, :created], %Item{name: "one"}}

      Items.subscribe(i.id)
      {:ok, _} = Items.create_or_update(i, %{name: "two"})
      assert_receive {[:item, :updated], %Item{name: "two"}}
      assert_receive {[:item, :updated], %Item{name: "two"}}

      Items.unsubscribe()
      Items.unsubscribe(i.id)
      {:ok, _} = Items.create_or_update(i, %{name: "three"})
      refute_receive {[:item, _], _}
    end

    test "invalid attrs return the changeset and broadcast nothing" do
      Items.subscribe()
      assert {:error, %Ecto.Changeset{} = cs} = Items.new() |> Items.create_or_update(%{})
      assert %{name: ["can't be blank"]} = errors_on(cs)
      refute_receive {[:item, _], _}
      assert Repo.aggregate(ItemArchive, :count) == 0
    end

    test "every successful save writes an archive row of the saved values" do
      i = item(%{name: "one", order: 5})
      {:ok, _} = Items.create_or_update(i, %{name: "two"})

      rows = ItemArchive |> order_by(:id) |> Repo.all()
      assert Enum.map(rows, &{&1.item_id, &1.name, &1.order}) == [{i.id, "one", 5}, {i.id, "two", 5}]
    end

    test "archiving works with string-keyed params, as LiveView forms send" do
      i = item(%{name: "one"})
      assert {:ok, %Item{name: "two"}} = Items.create_or_update(i, %{"name" => "two"})
      assert ItemArchive |> order_by(desc: :id) |> limit(1) |> Repo.one() |> Map.get(:name) == "two"
    end
  end

  test "get/new/new_changeset/change" do
    i = item(%{name: "x"})
    assert Items.get(i.id).name == "x"
    assert Items.get(-1) == nil
    assert %Item{id: nil} = Items.new()
    refute Items.new_changeset(%{}).valid?
    assert Items.new_changeset(%{name: "y"}).valid?
    assert %Ecto.Changeset{changes: %{name: "z"}} = Items.change(i, %{name: "z"})
  end

  test "delete/1 by struct or id broadcasts deleted" do
    a = item(%{name: "a"})
    b = item(%{name: "b"})
    Items.subscribe()

    assert {:ok, _} = Items.delete(a)
    assert {:ok, _} = Items.delete(b.id)
    assert_receive {[:item, :deleted], %Item{name: "a"}}
    assert_receive {[:item, :deleted], %Item{name: "b"}}
    assert Items.list() == []
  end

  test "activate/deactivate default to :active and accept another boolean field" do
    i = item(%{name: "x"})
    Items.subscribe(i.id)

    assert {:ok, %Item{active: false}} = Items.deactivate(i.id)
    assert_receive {[:item, :updated], %Item{active: false}}
    assert {:ok, %Item{active: true}} = Items.activate(i.id)
    assert {:ok, %Item{archive: true}} = Items.activate(i.id, :archive)
    assert {:ok, %Item{archive: false}} = Items.deactivate(i.id, :archive)
    assert %Item{active: true, archive: false} = Items.get(i.id)
  end

  describe "move_up/1" do
    test "swaps order with the nearest lower one, even across gaps, and broadcasts both" do
      first = item(%{name: "first", order: 10})
      second = item(%{name: "second", order: 20})
      third = item(%{name: "third", order: 40})
      Items.subscribe()

      Items.move_up(third.id)
      assert Items.get(third.id).order == 20
      assert Items.get(second.id).order == 40
      assert Items.get(first.id).order == 10
      assert_receive {[:item, :updated], %Item{name: "third", order: 20}}
      assert_receive {[:item, :updated], %Item{name: "second", order: 40}}

      names = Items.list(%{sort_stack: [%Sort{field: :order}]}) |> Enum.map(& &1.name)
      assert names == ["first", "third", "second"]
    end

    test "moving the top item up is a no-op" do
      top = item(%{name: "top", order: 1})
      _ = item(%{name: "next", order: 2})
      Items.move_up(top.id)
      assert Items.get(top.id).order == 1
    end
  end

  describe "a real DefaultCrud context (InfiniteScrollTest)" do
    test "creates, validates, lists paginated and deletes" do
      alias HfgPortal.InfiniteScrollTest, as: Ctx

      assert {:error, _} = Ctx.new() |> Ctx.create_or_update(%{})
      items = for n <- 1..5, do: elem(Ctx.new() |> Ctx.create_or_update(%{name: "item #{n}"}), 1)

      page = Ctx.list(%{sort_stack: [%Sort{field: :name, order: :desc}], page: 0, per_page: 2})
      assert Enum.map(page, & &1.name) == ["item 5", "item 4"]

      Enum.each(items, &Ctx.delete/1)
      assert Ctx.list() == []
    end
  end
end
