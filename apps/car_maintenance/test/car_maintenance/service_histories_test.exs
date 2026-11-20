defmodule CarMaintenance.ServiceHistoriesTest do
  use CarMaintenance.DataCase

  alias CarMaintenance.{Cars, MaintenanceItems, ServiceHistories}
  alias CarMaintenance.Cars.{Car, MaintenanceItem, ServiceHistory}

  defp car_fixture(attrs \\ %{}) do
    {:ok, car} = Cars.create_or_update(%Car{}, Map.merge(%{name: "Civic"}, attrs))
    car
  end

  defp item_fixture(car, attrs \\ %{}) do
    {:ok, item} = MaintenanceItems.create_or_update(%MaintenanceItem{}, Map.merge(%{name: "Oil", car_id: car.id, interval_miles: 5000}, attrs))
    item
  end

  defp sh_fixture(attrs) do
    {:ok, sh} = ServiceHistories.create_or_update(%ServiceHistory{}, attrs)
    sh
  end

  describe "ServiceHistory.changeset/2" do
    test "casts ISO date strings and integer mileage; named_item defaults to false" do
      cs = ServiceHistory.changeset(%ServiceHistory{}, %{service_date: "2024-02-29", mileage: "123456", notes: "n"})
      assert cs.valid?
      assert get_change(cs, :service_date) == ~D[2024-02-29]
      assert get_change(cs, :mileage) == 123_456
      assert get_field(cs, :named_item) == false
    end

    test "rejects impossible dates and non-numeric mileage" do
      assert %{service_date: ["is invalid"]} = errors_on(ServiceHistory.changeset(%ServiceHistory{}, %{service_date: "2023-02-29"}))
      assert %{mileage: ["is invalid"]} = errors_on(ServiceHistory.changeset(%ServiceHistory{}, %{mileage: "12k"}))
    end

    test "accepts a Date struct" do
      cs = ServiceHistory.changeset(%ServiceHistory{}, %{service_date: ~D[2025-01-01]})
      assert get_change(cs, :service_date) == ~D[2025-01-01]
    end
  end

  describe "create_or_update/2" do
    test "persists all fields and round-trips the date" do
      car = car_fixture()
      item = item_fixture(car)
      sh = sh_fixture(%{car_id: car.id, maintenance_item_id: item.id, service_date: "2024-06-15", mileage: 42_000, notes: "synthetic"})
      fetched = ServiceHistories.get(sh.id)
      assert fetched.service_date == ~D[2024-06-15]
      assert fetched.mileage == 42_000
      assert fetched.maintenance_item_id == item.id
      assert %ServiceHistory{car: %Car{id: cid}, maintenance_item: %MaintenanceItem{}} =
               ServiceHistories.preload(fetched, %{preload: [:car, :maintenance_item]})
      assert cid == car.id
    end

    test "rejects an unknown car (FK)" do
      assert_raise Ecto.ConstraintError, fn -> ServiceHistories.create_or_update(%ServiceHistory{}, %{car_id: -1}) end
    end

    test "broadcasts created/updated/deleted" do
      car = car_fixture()
      ServiceHistories.subscribe()
      sh = sh_fixture(%{car_id: car.id, mileage: 1})
      assert_receive {[:service_history, :created], %ServiceHistory{mileage: 1}}
      {:ok, _} = ServiceHistories.create_or_update(sh, %{mileage: 2})
      assert_receive {[:service_history, :updated], %ServiceHistory{mileage: 2}}
      {:ok, _} = ServiceHistories.delete(sh.id)
      assert_receive {[:service_history, :deleted], %ServiceHistory{}}
    end
  end

  describe "list/1" do
    setup do
      car = car_fixture()
      other = car_fixture(%{name: "Truck"})
      item = item_fixture(car)

      odometer = sh_fixture(%{car_id: car.id, mileage: 30_000, service_date: ~D[2024-03-01]})
      itemized = sh_fixture(%{car_id: car.id, maintenance_item_id: item.id, mileage: 31_000, service_date: ~D[2024-04-01]})
      named = sh_fixture(%{car_id: car.id, name: "Wipers", named_item: true, mileage: 29_000, service_date: ~D[2024-01-01]})
      foreign = sh_fixture(%{car_id: other.id, mileage: 99_000})

      %{car: car, other: other, odometer: odometer, itemized: itemized, named: named, foreign: foreign}
    end

    test "filters by car and orders by mileage, highest first", ctx do
      assert ServiceHistories.list(%{car_id: ctx.car.id}) |> Enum.map(& &1.id) == [ctx.itemized.id, ctx.odometer.id, ctx.named.id]
      assert ServiceHistories.list(%{car_id: ctx.other.id}) |> Enum.map(& &1.id) == [ctx.foreign.id]
      assert length(ServiceHistories.list(%{})) == 4
    end

    test "mileage: true keeps only plain odometer readings (no name and no item)", ctx do
      assert ServiceHistories.list(%{car_id: ctx.car.id, mileage: true}) |> Enum.map(& &1.id) == [ctx.odometer.id]
    end

    test "mileage: false keeps only real services (named or linked to an item)", ctx do
      assert ServiceHistories.list(%{car_id: ctx.car.id, mileage: false}) |> Enum.map(& &1.id) == [ctx.itemized.id, ctx.named.id]
    end

    test "equal mileage falls back to newest service date, then newest id", ctx do
      a = sh_fixture(%{car_id: ctx.other.id, mileage: 5, service_date: ~D[2024-01-01]})
      b = sh_fixture(%{car_id: ctx.other.id, mileage: 5, service_date: ~D[2024-02-01]})
      c = sh_fixture(%{car_id: ctx.other.id, mileage: 5, service_date: ~D[2024-02-01]})
      assert ServiceHistories.list(%{car_id: ctx.other.id}) |> Enum.map(& &1.id) == [ctx.foreign.id, c.id, b.id, a.id]
    end

    test "paginates", ctx do
      assert ServiceHistories.list(%{car_id: ctx.car.id, page: 1, per_page: 2}) |> Enum.map(& &1.id) == [ctx.named.id]
    end

    test "preloads", ctx do
      [first | _] = ServiceHistories.list(%{car_id: ctx.car.id, preload: [:maintenance_item]})
      assert %MaintenanceItem{} = first.maintenance_item
    end
  end

  describe "service_history_mileage_query/0 (car odometer summary)" do
    test "gives each car its highest recorded mileage and number of entries" do
      car = car_fixture()
      empty = car_fixture(%{name: "New"})
      other = car_fixture(%{name: "Other"})
      sh_fixture(%{car_id: car.id, mileage: 10_000})
      sh_fixture(%{car_id: car.id, mileage: 25_000})
      sh_fixture(%{car_id: car.id, mileage: 20_000})
      sh_fixture(%{car_id: other.id, mileage: 500})

      [car, empty, other] =
        Cars.preload([car, empty, other], %{preload: [service_history: ServiceHistories.service_history_mileage_query()]})

      assert %{mileage: 25_000, service_history: 3} = car.service_history
      assert empty.service_history == nil
      assert %{mileage: 500, service_history: 1} = other.service_history
    end

    test "entries without mileage are counted but do not lower the max" do
      car = car_fixture()
      sh_fixture(%{car_id: car.id, mileage: 7})
      sh_fixture(%{car_id: car.id, name: "No odometer"})
      car = Cars.preload(car, %{preload: [service_history: ServiceHistories.service_history_mileage_query()]})
      assert %{mileage: 7, service_history: 2} = car.service_history
    end
  end

  describe "service_history_query/0 (last service per maintenance item)" do
    test "gives each item its latest service date and highest mileage" do
      car = car_fixture()
      oil = item_fixture(car)
      tires = item_fixture(car, %{name: "Tires"})
      never = item_fixture(car, %{name: "Never done"})

      sh_fixture(%{car_id: car.id, maintenance_item_id: oil.id, mileage: 5_000, service_date: ~D[2023-01-10]})
      sh_fixture(%{car_id: car.id, maintenance_item_id: oil.id, mileage: 10_000, service_date: ~D[2023-07-10]})
      sh_fixture(%{car_id: car.id, maintenance_item_id: tires.id, mileage: 8_000, service_date: ~D[2023-05-01]})
      # odometer-only entries never count as an item's last service
      sh_fixture(%{car_id: car.id, mileage: 50_000, service_date: ~D[2024-01-01]})

      items = MaintenanceItems.list(%{car_id: car.id, preload: [last_service_history: ServiceHistories.service_history_query()]})
      by_name = Map.new(items, &{&1.name, &1.last_service_history})

      assert %{service_date: ~D[2023-07-10], mileage: 10_000} = by_name["Oil"]
      assert %{service_date: ~D[2023-05-01], mileage: 8_000} = by_name["Tires"]
      assert by_name["Never done"] == nil
      assert never.id
    end
  end
end
