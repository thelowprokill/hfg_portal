defmodule HfgPortalWeb.Apis.CarMaintenanceApiTest do
  use HfgPortalWeb.ApiCase

  alias CarMaintenance.{Cars, ServiceHistories, MaintenanceItems, MaintenanceImages}

  # car_maintenance only has the "None" and "Edit" roles (View/Admin are commented out in
  # CarMaintenance.Users.Roles), so :admin routes are unreachable for everyone.
  @routes [
    {"car_maintenance:cars", "GET", "cars", :view},
    {"car_maintenance:cars", "GET", "car", :view},
    {"car_maintenance:cars", "PUT", "car", :edit},
    {"car_maintenance:cars", "DELETE", "car", :admin},
    {"car_maintenance:service_history", "GET", "service_histories", :view},
    {"car_maintenance:service_history", "GET", "service_history", :view},
    {"car_maintenance:service_history", "PUT", "service_history", :edit},
    {"car_maintenance:maintenance_items", "GET", "maintenance_items", :view},
    {"car_maintenance:maintenance_images", "GET", "maintenance_images", :view},
    {"car_maintenance:maintenance_images", "GET", "maintenance_image", :view},
    {"car_maintenance:maintenance_images", "PUT", "maintenance_image", :edit},
    {"car_maintenance:maintenance_images", "DELETE", "maintenance_image", :admin}
  ]

  setup do
    editor = api_user(%{car_maintenance: "Edit"})
    %{editor: editor, jwt: token(editor)}
  end

  defp call(conn, jwt, method, scope, route, query \\ %{}, body \\ nil),
    do: api(conn, method, jwt, Map.merge(%{"scope" => "car_maintenance:" <> scope, "route" => route}, query), body)

  defp car(attrs \\ %{}) do
    {:ok, c} = Cars.create_or_update(Cars.new(), Map.merge(%{name: "Civic", year: 2015, make: "Honda", model: "Civic", vin: "VIN1", license_plate: "ABC123"}, attrs))
    c
  end

  defp item(car, attrs) do
    {:ok, i} = MaintenanceItems.create_or_update(MaintenanceItems.new(), Map.merge(%{car_id: car.id, name: "Oil"}, attrs))
    i
  end

  defp history(car, attrs) do
    {:ok, sh} = ServiceHistories.create_or_update(ServiceHistories.new(), Map.merge(%{car_id: car.id, service_date: ~D[2026-01-10], mileage: 1000}, attrs))
    sh
  end

  test "authorization: no role, None, and the non-existent Admin role are refused; Edit can't reach admin routes", %{conn: conn, jwt: jwt} do
    others = for role <- [nil, "None", "Admin", "View"], do: token(if(role, do: api_user(%{car_maintenance: role}), else: api_user()))

    for {scope, method, route, required} <- @routes, t <- (if required == :admin, do: [jwt | others], else: others) do
      assert %{"error" => "Unauthorized"} = conn |> api(method, t, %{"scope" => scope, "route" => route, "id" => "1"}) |> json_response(401),
             "#{method} #{scope}/#{route}"
    end

    assert %{"error" => "Route not found"} = conn |> call(jwt, "GET", "cars", "nope") |> json_response(404)
  end

  describe "cars" do
    test "lists cars with their highest mileage, delimited", %{conn: conn, jwt: jwt} do
      c = car()
      history(c, %{mileage: 123_456})
      history(c, %{mileage: 99})
      car(%{name: "Truck", vin: "VIN2"})

      cars = conn |> call(jwt, "GET", "cars", "cars") |> data()
      assert %{"mileage" => "123,456", "vin" => "VIN1", "license_plate" => "ABC123", "year" => 2015} = Enum.find(cars, &(&1["id"] == c.id))
      assert %{"mileage" => nil} = Enum.find(cars, &(&1["name"] == "Truck"))
    end

    test "gets one car", %{conn: conn, jwt: jwt} do
      c = car()
      assert %{"id" => id, "make" => "Honda", "model" => "Civic"} = conn |> call(jwt, "GET", "cars", "car", %{"id" => "#{c.id}"}) |> data()
      assert id == c.id
    end

    test "PUT creates a car from query params, then updates it by id, ignoring blank fields", %{conn: conn, jwt: jwt} do
      assert %{"id" => id, "name" => "Wagon", "year" => 2020} =
               conn |> call(jwt, "PUT", "cars", "car", %{"name" => "Wagon", "year" => "2020", "vin" => ""}) |> data()

      assert %{"id" => ^id, "name" => "Wagon", "model" => "Outback"} =
               conn |> call(jwt, "PUT", "cars", "car", %{"id" => "#{id}", "model" => "Outback", "name" => ""}) |> data()

      assert Cars.get(id).model == "Outback"
    end
  end

  describe "service_history" do
    test "lists a car's service history (not plain mileage entries) with next service", %{conn: conn, jwt: jwt} do
      c = car()
      by_miles = item(c, %{name: "Oil", interval_miles: 5000})
      by_months = item(c, %{name: "Wipers", interval_months: 2})
      history(c, %{maintenance_item_id: by_miles.id, mileage: 10_000})
      history(c, %{maintenance_item_id: by_months.id, mileage: 9_000, service_date: ~D[2026-01-01]})
      history(c, %{named_item: true, name: "Tyres", mileage: 8_000})
      history(c, %{mileage: 11_000})
      history(car(%{vin: "other"}), %{named_item: true, name: "Other car", mileage: 1})

      rows = conn |> call(jwt, "GET", "service_history", "service_histories", %{"car_id" => "#{c.id}"}) |> data()

      assert Enum.map(rows, &{&1["item"], &1["next_service"]}) == [
               {"Oil", 15_000},
               {"Wipers", "2026-03-02"},
               {"Tyres", nil}
             ]
    end

    test "PUT creates a named entry, or one for a maintenance item, and updates by id", %{conn: conn, jwt: jwt, editor: editor} do
      c = car()
      oil = item(c, %{name: "Oil", interval_miles: 3000})

      q = %{"car_id" => "#{c.id}", "service_date" => "2026-02-01", "mileage" => "500", "name" => "Brakes", "notes" => "front"}
      assert %{"id" => id, "item" => "Brakes", "next_service" => nil, "mileage" => 500, "service_date" => "2026-02-01"} =
               conn |> call(jwt, "PUT", "service_history", "service_history", q) |> data()

      sh = ServiceHistories.get(id)
      assert {sh.named_item, sh.created_by_id, sh.updated_by_id} == {true, editor.id, editor.id}

      q = %{"car_id" => "#{c.id}", "service_date" => "2026-02-01", "mileage" => "600", "item_id" => "#{oil.id}"}
      assert %{"item" => "Oil", "next_service" => 3600} = conn |> call(jwt, "PUT", "service_history", "service_history", q) |> data()

      assert %{"id" => ^id, "notes" => "rear"} =
               conn |> call(jwt, "PUT", "service_history", "service_history", %{"id" => "#{id}", "notes" => "rear", "name" => "Brakes"}) |> data()

      assert %{"id" => ^id, "item" => "Brakes"} = conn |> call(jwt, "GET", "service_history", "service_history", %{"id" => "#{id}"}) |> data()
    end
  end

  test "maintenance_items lists a car's items", %{conn: conn, jwt: jwt} do
    c = car()
    item(c, %{name: "Oil", interval_miles: 5000, notes: "5w30"})
    item(car(%{vin: "x"}), %{name: "Not mine"})

    assert [%{"name" => "Oil", "interval_miles" => 5000, "interval_months" => nil, "notes" => "5w30"}] =
             conn |> call(jwt, "GET", "maintenance_items", "maintenance_items", %{"car_id" => "#{c.id}"}) |> data()
  end

  describe "maintenance_images" do
    @tag :tmp_dir
    test "PUT uploads an image (multipart), list/get return it as a data URI", %{conn: conn, jwt: jwt, tmp_dir: tmp} do
      sh = history(car(), %{named_item: true, name: "Brakes"})
      path = Path.join(tmp, "pic.png")
      File.write!(path, <<137, 80, 78, 71, 1, 2, 3>>)
      uri = "data:image/png;base64," <> Base.encode64(<<137, 80, 78, 71, 1, 2, 3>>)

      body = %{
        "name" => "pads",
        "image_content_type" => "image/png",
        "service_history_id" => "#{sh.id}",
        "image" => %Plug.Upload{path: path, filename: "pic.png", content_type: "image/png"}
      }

      assert %{"id" => id, "name" => "pads", "image" => ^uri, "image_content_type" => "image/png"} =
               conn |> call(jwt, "PUT", "maintenance_images", "maintenance_image", %{}, body) |> data()

      assert MaintenanceImages.get(id).service_history_id == sh.id

      assert [%{"id" => ^id, "image" => ^uri}] =
               conn |> call(jwt, "GET", "maintenance_images", "maintenance_images", %{"service_history_id" => "#{sh.id}"}) |> data()

      assert %{"id" => ^id, "image" => ^uri} = conn |> call(jwt, "GET", "maintenance_images", "maintenance_image", %{"id" => "#{id}"}) |> data()
    end
  end
end
