defmodule CarMaintenance.CarsTest do
  use CarMaintenance.DataCase

  alias CarMaintenance.{Cars, MaintenanceItems, ServiceHistories, MaintenanceImages}
  alias CarMaintenance.Cars.{Car, MaintenanceItem, ServiceHistory, MaintenanceImage}

  defp car_fixture(attrs \\ %{}) do
    {:ok, car} = Cars.create_or_update(%Car{}, Map.merge(%{name: "Civic", year: 2015, make: "Honda", model: "Civic"}, attrs))
    car
  end

  defp item_fixture(car, attrs \\ %{}) do
    {:ok, item} = MaintenanceItems.create_or_update(%MaintenanceItem{}, Map.merge(%{name: "Oil change", interval_miles: 5000, car_id: car.id}, attrs))
    item
  end

  describe "Car.changeset/2" do
    test "casts every editable field and defaults active to true" do
      cs = Car.changeset(%Car{}, %{name: "Truck", year: "2004", make: "Ford", model: "F-150", vin: "1FT", license_plate: "ABC123"})
      assert cs.valid?
      assert get_change(cs, :year) == 2004
      assert get_field(cs, :active) == true
    end

    test "rejects a non-numeric year" do
      cs = Car.changeset(%Car{}, %{year: "nineteen"})
      refute cs.valid?
      assert %{year: ["is invalid"]} = errors_on(cs)
    end

    test "ignores fields that are not castable (id, timestamps)" do
      cs = Car.changeset(%Car{}, %{id: 999, inserted_at: ~N[2020-01-01 00:00:00], name: "x"})
      assert cs.changes == %{name: "x"}
    end

    test "has no required fields, so an empty car is valid" do
      assert Car.changeset(%Car{}, %{}).valid?
    end
  end

  describe "Cars CRUD" do
    test "create_or_update/2 inserts, then updates the same row" do
      user = user_fixture()
      car = car_fixture(%{created_by_id: user.id})
      assert car.id
      assert car.created_by_id == user.id
      assert Cars.get(car.id).name == "Civic"

      {:ok, updated} = Cars.create_or_update(car, %{name: "Old Civic", updated_by_id: user.id})
      assert updated.id == car.id
      assert Cars.get(car.id).name == "Old Civic"
      assert length(Cars.list()) == 1
    end

    test "create_or_update/2 returns the changeset on invalid input and writes nothing" do
      assert {:error, %Ecto.Changeset{}} = Cars.create_or_update(%Car{}, %{year: "abc"})
      assert Cars.list() == []
    end

    test "create_or_update/2 rejects an unknown created_by user (FK)" do
      assert_raise Ecto.ConstraintError, fn -> Cars.create_or_update(%Car{}, %{created_by_id: -1}) end
    end

    test "new/0, new_changeset/1 and change/2" do
      assert %Car{id: nil} = Cars.new()
      assert get_change(Cars.new_changeset(%{name: "a"}), :name) == "a"
      car = car_fixture()
      assert get_change(Cars.change(car, %{make: "Toyota"}), :make) == "Toyota"
    end

    test "get/1 returns nil for a missing id" do
      assert Cars.get(-1) == nil
    end

    test "activate/deactivate by struct and by id" do
      car = car_fixture()
      assert {:ok, %Car{active: false}} = Cars.deactivate(car)
      assert {:ok, %Car{active: true}} = Cars.activate(car.id)
      assert {:ok, %Car{active: false}} = Cars.deactivate(car.id)
      refute Cars.get(car.id).active
    end

    test "delete/1 by struct and by id" do
      a = car_fixture()
      b = car_fixture()
      assert {:ok, _} = Cars.delete(a)
      assert {:ok, _} = Cars.delete(b.id)
      assert Cars.list() == []
    end

    test "delete/1 with an unknown id raises instead of returning an error" do
      assert_raise ArgumentError, fn -> Cars.delete(-1) end
    end

    test "deleting a car cascades to its maintenance items" do
      car = car_fixture()
      item = item_fixture(car)
      {:ok, _} = Cars.delete(car)
      assert MaintenanceItems.get(item.id) == nil
    end

    test "a car that has service history cannot be deleted (history FK is restrictive)" do
      car = car_fixture()
      {:ok, _} = ServiceHistories.create_or_update(%ServiceHistory{}, %{car_id: car.id, mileage: 1000})
      assert_raise Ecto.ConstraintError, fn -> Cars.delete(car) end
    end
  end

  describe "Cars.list/1" do
    setup do
      cars = [
        car_fixture(%{name: "Civic", year: 2015, make: "Honda"}),
        car_fixture(%{name: "Accord", year: 2010, make: "Honda", active: false}),
        car_fixture(%{name: "Tacoma", year: 2020, make: "Toyota"}),
      ]
      %{cars: cars}
    end

    test "filters on active" do
      assert Cars.list(%{active: true}) |> Enum.map(& &1.name) |> Enum.sort() == ["Civic", "Tacoma"]
      assert [%Car{name: "Accord"}] = Cars.list(%{active: false})
      assert length(Cars.list(%{active: nil})) == 3
    end

    test "search_stack does a case-sensitive substring match" do
      assert [%Car{name: "Tacoma"}] = Cars.list(%{search_stack: [%{field: :make, val: "Toy"}]})
      assert Cars.list(%{search_stack: [%{field: :make, val: "toy"}]}) == []
    end

    test "search_stack combines criteria with AND, empty value matches all, unknown fields are ignored" do
      stack = [%{field: :make, val: "Honda"}, %{field: :name, val: "Civ"}]
      assert [%Car{name: "Civic"}] = Cars.list(%{search_stack: stack})
      assert length(Cars.list(%{search_stack: [%{field: :name, val: ""}]})) == 3
      assert length(Cars.list(%{search_stack: [%{field: :nope, val: "x"}]})) == 3
    end

    test "search_stack on inserted_at keeps rows inserted at or after the value" do
      assert length(Cars.list(%{search_stack: [%{field: :inserted_at, val: ~N[2000-01-01 00:00:00]}]})) == 3
      assert Cars.list(%{search_stack: [%{field: :inserted_at, val: ~N[2999-01-01 00:00:00]}]}) == []
    end

    test "sort_stack orders by a schema field and ignores unknown fields" do
      assert Cars.list(%{sort_stack: [%{field: :year, order: :desc}]}) |> Enum.map(& &1.year) == [2020, 2015, 2010]
      assert Cars.list(%{sort_stack: [%{field: :year, order: :asc}, %{field: :bogus, order: :asc}]}) |> Enum.map(& &1.year) == [2010, 2015, 2020]
    end

    test "pagination is zero-based and accepts string params" do
      sort = [%{field: :year, order: :asc}]
      assert Cars.list(%{sort_stack: sort, page: 0, per_page: 2}) |> Enum.map(& &1.year) == [2010, 2015]
      assert Cars.list(%{sort_stack: sort, page: "1", per_page: "2"}) |> Enum.map(& &1.year) == [2020]
      assert Cars.list(%{sort_stack: sort, page: 5, per_page: 2}) == []
      # only one of page/per_page given: no pagination
      assert length(Cars.list(%{page: 0})) == 3
    end
  end

  describe "Cars PubSub" do
    test "create, update, activate and delete broadcast on the topic and the per-id topic" do
      Cars.subscribe()
      car = car_fixture(%{name: "Pub"})
      assert_receive {[:car, :created], %Car{id: id, name: "Pub"}}
      assert id == car.id

      Cars.subscribe(car.id)
      {:ok, _} = Cars.create_or_update(car, %{name: "Pub2"})
      assert_receive {[:car, :updated], %Car{name: "Pub2"}}
      assert_receive {[:car, :updated], %Car{name: "Pub2"}}

      {:ok, _} = Cars.deactivate(car.id)
      assert_receive {[:car, :updated], %Car{active: false}}

      {:ok, _} = Cars.delete(car.id)
      assert_receive {[:car, :deleted], %Car{id: ^id}}
      assert_receive {[:car, :deleted], %Car{id: ^id}}
    end

    test "a failed write broadcasts nothing" do
      Cars.subscribe()
      {:error, _} = Cars.create_or_update(%Car{}, %{year: "x"})
      refute_receive {[:car, _], _}
    end

    test "unsubscribe stops delivery" do
      Cars.subscribe()
      Cars.unsubscribe()
      car_fixture()
      refute_receive {[:car, :created], _}
    end

    test "per-id subscribers only hear about their own record" do
      a = car_fixture()
      b = car_fixture()
      Cars.subscribe(a.id)
      {:ok, _} = Cars.create_or_update(b, %{name: "other"})
      refute_receive {[:car, :updated], _}
      Cars.unsubscribe(a.id)
      {:ok, _} = Cars.create_or_update(a, %{name: "mine"})
      refute_receive {[:car, :updated], _}
    end
  end

  describe "MaintenanceItems" do
    test "changeset casts intervals and defaults active" do
      cs = MaintenanceItem.changeset(%MaintenanceItem{}, %{name: "Tires", interval_miles: "7500", interval_months: "6", notes: "rotate"})
      assert cs.valid?
      assert get_change(cs, :interval_miles) == 7500
      assert get_change(cs, :interval_months) == 6
      assert get_field(cs, :active)
      refute MaintenanceItem.changeset(%MaintenanceItem{}, %{interval_miles: "lots"}).valid?
    end

    test "list/1 filters by car and active and orders by name" do
      civic = car_fixture()
      truck = car_fixture(%{name: "Truck"})
      item_fixture(civic, %{name: "Tires"})
      item_fixture(civic, %{name: "Air filter", active: false})
      item_fixture(civic, %{name: "Brakes"})
      item_fixture(truck, %{name: "Oil"})

      assert MaintenanceItems.list(%{car_id: civic.id}) |> Enum.map(& &1.name) == ["Air filter", "Brakes", "Tires"]
      assert MaintenanceItems.list(%{car_id: civic.id, active: true}) |> Enum.map(& &1.name) == ["Brakes", "Tires"]
      assert MaintenanceItems.list(%{}) |> length() == 4
      assert MaintenanceItems.list(%{car_id: civic.id, page: 1, per_page: 2}) |> Enum.map(& &1.name) == ["Tires"]
    end

    test "list/1 applies sort_stack before the default name order" do
      car = car_fixture()
      item_fixture(car, %{name: "A", interval_miles: 1000})
      item_fixture(car, %{name: "B", interval_miles: 9000})
      assert MaintenanceItems.list(%{sort_stack: [%{field: :interval_miles, order: :desc}]}) |> Enum.map(& &1.name) == ["B", "A"]
    end

    test "list/1 preloads associations" do
      car = car_fixture()
      item_fixture(car)
      assert [%MaintenanceItem{car: %Car{id: id}}] = MaintenanceItems.list(%{preload: [:car]})
      assert id == car.id
    end

    test "an item that has service history cannot be deleted" do
      car = car_fixture()
      item = item_fixture(car)
      {:ok, _} = ServiceHistories.create_or_update(%ServiceHistory{}, %{car_id: car.id, maintenance_item_id: item.id, mileage: 10})
      assert_raise Ecto.ConstraintError, fn -> MaintenanceItems.delete(item) end
    end

    test "CRUD broadcasts" do
      car = car_fixture()
      MaintenanceItems.subscribe()
      item = item_fixture(car)
      assert_receive {[:maintenance_item, :created], %MaintenanceItem{}}
      {:ok, _} = MaintenanceItems.deactivate(item)
      assert_receive {[:maintenance_item, :updated], %MaintenanceItem{active: false}}
      {:ok, _} = MaintenanceItems.delete(item.id)
      assert_receive {[:maintenance_item, :deleted], %MaintenanceItem{}}
    end
  end

  describe "MaintenanceImages" do
    setup do
      car = car_fixture()
      {:ok, sh} = ServiceHistories.create_or_update(%ServiceHistory{}, %{car_id: car.id, mileage: 100, name: "Oil"})
      %{car: car, sh: sh}
    end

    # a few bytes of a PNG header, including NUL and high bytes
    @png <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 255>>

    test "stores and returns binary image data byte for byte with its content type", %{sh: sh} do
      user = user_fixture()
      {:ok, img} = MaintenanceImages.create_or_update(%MaintenanceImage{}, %{
        name: "receipt.png", service_history_id: sh.id, image: @png, image_content_type: "image/png", created_by_id: user.id,
      })
      fetched = MaintenanceImages.get(img.id)
      assert fetched.image == @png
      assert fetched.image_content_type == "image/png"
      assert fetched.name == "receipt.png"
    end

    test "changeset rejects non-binary image data" do
      refute MaintenanceImage.changeset(%MaintenanceImage{}, %{image: 123}).valid?
    end

    test "list/1 filters by service history and orders by name", %{car: car, sh: sh} do
      {:ok, other} = ServiceHistories.create_or_update(%ServiceHistory{}, %{car_id: car.id, mileage: 200})
      for {name, id} <- [{"b.jpg", sh.id}, {"a.jpg", sh.id}, {"c.jpg", other.id}] do
        {:ok, _} = MaintenanceImages.create_or_update(%MaintenanceImage{}, %{name: name, service_history_id: id, image: "x"})
      end

      assert MaintenanceImages.list(%{service_history_id: sh.id}) |> Enum.map(& &1.name) == ["a.jpg", "b.jpg"]
      assert MaintenanceImages.list(%{service_history_id: nil}) |> Enum.map(& &1.name) == ["a.jpg", "b.jpg", "c.jpg"]
      assert [%MaintenanceImage{service_history: %ServiceHistory{id: oid}}] =
               MaintenanceImages.list(%{service_history_id: other.id, preload: [:service_history]})
      assert oid == other.id
    end

    test "images are deleted with their service history", %{sh: sh} do
      {:ok, img} = MaintenanceImages.create_or_update(%MaintenanceImage{}, %{name: "a", service_history_id: sh.id, image: "x"})
      {:ok, _} = ServiceHistories.delete(sh)
      assert MaintenanceImages.get(img.id) == nil
    end

    test "CRUD broadcasts", %{sh: sh} do
      MaintenanceImages.subscribe()
      {:ok, img} = MaintenanceImages.create_or_update(%MaintenanceImage{}, %{name: "a", service_history_id: sh.id, image: "x"})
      assert_receive {[:maintenance_image, :created], %MaintenanceImage{name: "a"}}
      {:ok, _} = MaintenanceImages.delete(img)
      assert_receive {[:maintenance_image, :deleted], %MaintenanceImage{name: "a"}}
    end
  end
end
