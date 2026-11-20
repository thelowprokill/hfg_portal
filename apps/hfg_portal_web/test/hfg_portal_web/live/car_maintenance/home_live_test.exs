defmodule HfgPortalWeb.CarMaintenance.HomeLiveTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortalWeb.LiveFixtures2

  alias CarMaintenance.{Cars, MaintenanceItems, MaintenanceImages, ServiceHistories, UserRoles}

  @page "car_maintenance,home"
  @png <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82>>

  defp car_fixture(attrs \\ %{}) do
    {:ok, car} =
      Cars.create_or_update(Cars.new(), Enum.into(attrs, %{name: "Car #{System.unique_integer([:positive])}", year: 2015, make: "Honda", model: "Civic"}))

    car
  end

  defp item_fixture(car, attrs \\ %{}) do
    {:ok, item} = MaintenanceItems.create_or_update(MaintenanceItems.new(), Enum.into(attrs, %{name: "Oil change", interval_miles: 5000, car_id: car.id}))
    item
  end

  defp history_fixture(car, attrs) do
    {:ok, sh} = ServiceHistories.create_or_update(ServiceHistories.new(), Enum.into(attrs, %{car_id: car.id, service_date: ~D[2026-01-01]}))
    sh
  end

  defp car_rows(page), do: count(page, ~s(tr[phx-click="service_history"]))

  setup %{conn: conn} do
    user = user_with_role(UserRoles, "Edit", %{first_name: "Carl"})
    %{conn: log_in_user(conn, user), user: user}
  end

  describe "authorization" do
    test "an Edit user gets the page and the Car Maintenance links", %{conn: conn} do
      {view, page} = open_page(conn, @page)
      assert page.module == HfgPortalWeb.CarMaintenance.Home.HomeLive
      assert render(page) =~ "Car Maintenance · Home"

      assert has_element?(view, ~s(a[href="/?page=car_maintenance,home"]))
      refute has_element?(view, ~s(a[href="/?page=car_maintenance,users"]))
    end

    test "a user without a role, or with None, gets the portal home instead", %{conn: conn} do
      none = user_with_role(UserRoles, "None")
      nobody = HfgPortal.AccountsFixtures.user_fixture()

      for user <- [none, nobody] do
        {view, page} = open_page(log_in_user(conn, user), @page)
        assert page.module == HfgPortalWeb.Home.HomeLive
        refute has_element?(view, ~s(a[href="/?page=car_maintenance,home"]))
      end
    end

    test "losing the role while on the page sends the user away", %{conn: conn, user: user} do
      {view, _page} = open_page(conn, @page)
      set_role(UserRoles, user, "None")
      assert_redirect(view, "/?page=car_maintenance,home")
    end

    test "logged out visitors are sent to log in" do
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(build_conn(), "/?page=#{@page}")
    end
  end

  describe "car list" do
    test "shows each car with its latest mileage, and delete only while it has no history", %{conn: conn} do
      fresh = car_fixture(%{name: "Fresh", license_plate: "ABC123"})
      used = car_fixture(%{name: "Used"})
      history_fixture(used, %{mileage: 1000})
      history_fixture(used, %{mileage: 123_456})

      {_view, page} = open_page(conn, @page)
      html = render(page)

      assert html =~ "Fresh"
      assert html =~ "ABC123"
      assert html =~ "123,456"
      assert has_element?(page, ~s(button[phx-click="delete"][phx-value-id="#{fresh.id}"]))
      refute has_element?(page, ~s(button[phx-click="delete"][phx-value-id="#{used.id}"]))
    end

    test "searching by name narrows the list and reset brings it back", %{conn: conn} do
      car_fixture(%{name: "Odyssey"})
      car_fixture(%{name: "Corolla"})
      {_view, page} = open_page(conn, @page)

      render_click(page, "search", %{"field" => "name"})
      render_change(page, "search", %{"search" => %{"field" => "name", "val" => "Odys"}})
      html = render(page)
      assert html =~ "Odyssey"
      refute html =~ "Corolla"

      render_click(page, "reset_filters", %{"field" => "name"})
      assert render(page) =~ "Corolla"
    end

    test "searching the year column filters instead of crashing", %{conn: conn} do
      car_fixture(%{name: "Old", year: 1999})
      car_fixture(%{name: "Brandnew", year: 2024})
      {_view, page} = open_page(conn, @page)

      render_click(page, "search", %{"field" => "year"})
      render_change(page, "search", %{"search" => %{"field" => "year", "val" => "1999"}})
      html = render(page)
      assert html =~ "Old"
      refute html =~ "Brandnew"
    end

    test "sorting by name asc then desc", %{conn: conn} do
      for name <- ~w(Bravo Alpha Charlie), do: car_fixture(%{name: name})
      {_view, page} = open_page(conn, @page)

      render_click(page, "sort", %{"field" => "name"})
      assert names(page) == ~w(Alpha Bravo Charlie)

      render_click(page, "sort", %{"field" => "name"})
      assert names(page) == ~w(Charlie Bravo Alpha)
    end

    test "shows 50 cars and loads more", %{conn: conn} do
      for _ <- 1..55, do: car_fixture()
      {_view, page} = open_page(conn, @page)

      assert car_rows(page) == 50
      render_click(page, "load_more", %{})
      assert car_rows(page) == 55
    end

    test "cars created, updated and deleted elsewhere show up live", %{conn: conn} do
      car = car_fixture(%{name: "Before"})
      {_view, page} = open_page(conn, @page)

      {:ok, _} = Cars.create_or_update(car, %{name: "After"})
      assert render(page) =~ "After"

      other = car_fixture(%{name: "Brand New"})
      assert render(page) =~ "Brand New"

      Cars.delete(other)
      refute render(page) =~ "Brand New"
    end
  end

  describe "car modal" do
    test "creating a car: invalid input shows errors, a valid one saves", %{conn: conn, user: user} do
      {_view, page} = open_page(conn, @page)

      render_click(page, "add_new", %{})
      assert has_element?(page, "#car")

      html = page |> form("#car form", %{"car" => %{"name" => "Truck", "year" => "abc"}}) |> render_change()
      assert html =~ "is invalid"

      page |> form("#car form", %{"car" => %{"name" => "Truck", "year" => "abc"}}) |> render_submit()
      assert has_element?(page, "#car")
      assert Cars.list(%{}) == []

      page
      |> form("#car form", %{"car" => %{"name" => "Truck", "year" => "2020", "make" => "Ford", "model" => "F150", "vin" => "VIN1", "license_plate" => "TRK1"}})
      |> render_submit()

      refute has_element?(page, "#car")
      assert [car] = Cars.list(%{})
      assert %{name: "Truck", year: 2020, make: "Ford", vin: "VIN1", created_by_id: id, updated_by_id: id} = car
      assert id == user.id
      assert render(page) =~ "Truck"
    end

    test "editing a car saves the change", %{conn: conn} do
      car = car_fixture(%{name: "Old Name"})
      {_view, page} = open_page(conn, @page)

      render_click(page, "edit", %{"id" => "#{car.id}"})
      page |> form("#car form", %{"car" => %{"name" => "New Name"}}) |> render_submit()

      assert Cars.get(car.id).name == "New Name"
      html = render(page)
      assert html =~ "New Name"
      refute html =~ "Old Name"
    end

    test "cancel closes the modal", %{conn: conn} do
      {_view, page} = open_page(conn, @page)
      render_click(page, "add_new", %{})
      render_click(page, "cancel", %{})
      refute has_element?(page, "#car")
    end

    test "deleting a car without history removes it", %{conn: conn} do
      car = car_fixture(%{name: "Gone Soon"})
      {_view, page} = open_page(conn, @page)

      render_click(page, "delete", %{"id" => "#{car.id}"})
      assert Cars.get(car.id) == nil
      refute render(page) =~ "Gone Soon"
    end
  end

  describe "mileage modal" do
    test "logging mileage records it and updates the row", %{conn: conn} do
      car = car_fixture()
      {_view, page} = open_page(conn, @page)

      render_click(page, "mileage", %{"id" => "#{car.id}"})
      page
      |> form("#car form", %{"service_history" => %{"service_date" => "2026-03-04", "mileage" => "45678"}})
      |> render_submit()

      assert [sh] = ServiceHistories.list(%{car_id: car.id})
      assert %{mileage: 45678, service_date: ~D[2026-03-04], maintenance_item_id: nil, name: nil} = sh
      refute has_element?(page, "#car")
      # HomeLive then reloads the row's mileage with CarMaintenance.Repo, which can't see this
      # test's sandboxed HfgPortal.Repo data, so the live row update isn't checked here.
    end

    test "a mileage log records who logged it", %{conn: conn, user: user} do
      car = car_fixture()
      {_view, page} = open_page(conn, @page)
      render_click(page, "mileage", %{"id" => "#{car.id}"})
      page |> form("#car form", %{"service_history" => %{"mileage" => "1"}}) |> render_submit()
      assert [%{created_by_id: id}] = ServiceHistories.list(%{car_id: car.id})
      assert id == user.id
    end

    test "starts from the car's current mileage", %{conn: conn} do
      car = car_fixture()
      history_fixture(car, %{mileage: 9999})
      {_view, page} = open_page(conn, @page)

      render_click(page, "mileage", %{"id" => "#{car.id}"})
      assert has_element?(page, ~s(input[name="service_history[mileage]"][value="9999"]))
    end
  end

  describe "modal contents" do
    test "service history lists the car's service records, not mileage logs or other cars'", %{conn: conn} do
      car = car_fixture(%{name: "Wagon"})
      item = item_fixture(car, %{name: "Tire rotation", interval_miles: 7500})
      history_fixture(car, %{mileage: 10_000, maintenance_item_id: item.id, notes: "front first"})
      history_fixture(car, %{mileage: 11_000})
      other = car_fixture()
      history_fixture(other, %{mileage: 22_000, name: "Other car wash", named_item: true})

      {_view, page} = open_page(conn, @page)
      render_click(page, "service_history", %{"id" => "#{car.id}"})
      html = page |> find_live_child("modal_service_history_service_history") |> render()

      assert html =~ "Wagon - Service History"
      assert html =~ "front first"
      # next due = mileage + interval
      assert html =~ "17500"
      refute html =~ "11,000"
      refute html =~ "Other car wash"
    end

    test "maintenance items lists only this car's items", %{conn: conn} do
      car = car_fixture(%{name: "Van"})
      item_fixture(car, %{name: "Brake fluid"})
      item_fixture(car_fixture(), %{name: "Someone else's filter"})

      {_view, page} = open_page(conn, @page)
      render_click(page, "maintenance_items", %{"id" => "#{car.id}"})
      html = page |> find_live_child("modal_maintenance_items_maintenance_items") |> render()

      assert html =~ "Van - Maintenance Items"
      assert html =~ "Brake fluid"
      refute html =~ "Someone else"
    end
  end

  describe "service history modal" do
    setup %{conn: conn} do
      car = car_fixture(%{name: "Wagon"})
      item = item_fixture(car, %{name: "Tire rotation", interval_miles: 7500})
      {_view, page} = open_page(conn, @page)
      render_click(page, "service_history", %{"id" => "#{car.id}"})
      modal = find_live_child(page, "modal_service_history_service_history")
      %{car: car, item: item, page: page, modal: modal}
    end

    test "adding a service record for a maintenance item", %{car: car, item: item, modal: modal, user: user} do
      modal
      |> form("form", %{"service_history" => %{
        "service_date" => "2026-05-06", "mileage" => "20000", "maintenance_item_id" => "#{item.id}", "notes" => "done"
      }})
      |> render_submit()

      assert [sh] = ServiceHistories.list(%{car_id: car.id})
      assert %{maintenance_item_id: maintenance_item_id, mileage: 20000, notes: "done", created_by_id: created_by} = sh
      assert maintenance_item_id == item.id
      assert created_by == user.id

      assert has_element?(modal, "#item_#{sh.id}", "Tire rotation")
    end

    test "a named record takes a free-text name", %{car: car, modal: modal} do
      html = modal |> form("form", %{"service_history" => %{"named_item" => "true"}}) |> render_change()
      assert html =~ ~s(name="service_history[name]")

      modal
      |> form("form", %{"service_history" => %{"named_item" => "true", "name" => "Windshield", "mileage" => "100"}})
      |> render_submit()

      assert [%{named_item: true, name: "Windshield"}] = ServiceHistories.list(%{car_id: car.id})
      assert render(modal) =~ "Windshield"
    end

    test "editing and deleting a record", %{car: car, item: item, modal: modal} do
      sh = history_fixture(car, %{mileage: 500, maintenance_item_id: item.id})
      assert has_element?(modal, "#item_#{sh.id}")

      render_click(modal, "edit", %{"id" => "#{sh.id}"})
      modal |> form("form", %{"service_history" => %{"mileage" => "600"}}) |> render_submit()
      assert ServiceHistories.get(sh.id).mileage == 600

      render_click(modal, "delete", %{"id" => "#{sh.id}"})
      assert ServiceHistories.get(sh.id) == nil
      refute has_element?(modal, "#item_#{sh.id}")
    end

    test "done closes it", %{page: page} do
      modal = find_live_child(page, "modal_service_history_service_history")
      render_click(modal, "cancel", %{})
      assert find_live_child(page, "modal_service_history_service_history") == nil
    end

    test "survives a mileage log for the open car", %{car: car, modal: modal} do
      history_fixture(car, %{mileage: 123})
      assert render(modal) =~ "Service History"
    end

    test "survives another car's service record being updated", %{modal: modal} do
      other = car_fixture()
      sh = history_fixture(other, %{mileage: 1})
      {:ok, _} = ServiceHistories.create_or_update(sh, %{mileage: 2})
      assert render(modal) =~ "Service History"
    end

    test "the Images button opens the images modal for that record", %{car: car, item: item, page: page} do
      sh = history_fixture(car, %{mileage: 300, maintenance_item_id: item.id})
      modal = find_live_child(page, "modal_service_history_service_history")

      render_click(modal, "maintenance_images", %{"id" => "#{sh.id}"})
      images = find_live_child(page, "modal_maintenance_images_maintenance_images")
      assert render(images) =~ "Tire rotation - Maintenance Images"
    end
  end

  describe "maintenance items modal" do
    setup %{conn: conn} do
      car = car_fixture(%{name: "Van"})
      {_view, page} = open_page(conn, @page)
      render_click(page, "maintenance_items", %{"id" => "#{car.id}"})
      %{car: car, page: page, modal: find_live_child(page, "modal_maintenance_items_maintenance_items")}
    end

    test "adding an item", %{car: car, modal: modal} do
      modal
      |> form("form", %{"maintenance_item" => %{"name" => "Coolant", "interval_miles" => "30000", "interval_months" => "24", "notes" => "pink"}})
      |> render_submit()

      assert [item] = MaintenanceItems.list(%{car_id: car.id})
      assert %{name: "Coolant", interval_miles: 30000, interval_months: 24, notes: "pink", active: true} = item
      assert has_element?(modal, "#item_#{item.id}", "Coolant")
    end

    test "invalid numbers show an error and don't save", %{car: car, modal: modal} do
      html = modal |> form("form", %{"maintenance_item" => %{"name" => "X", "interval_miles" => "lots"}}) |> render_submit()
      assert html =~ "is invalid"
      assert MaintenanceItems.list(%{car_id: car.id}) == []
    end

    test "a new item records who created it", %{car: car, modal: modal, user: user} do
      modal |> form("form", %{"maintenance_item" => %{"name" => "Belt"}}) |> render_submit()
      assert [%{created_by_id: id}] = MaintenanceItems.list(%{car_id: car.id})
      assert id == user.id
    end

    test "editing an item", %{car: car, modal: modal} do
      item = item_fixture(car, %{name: "Spark plugs"})
      render_click(modal, "edit", %{"id" => "#{item.id}"})
      modal |> form("form", %{"maintenance_item" => %{"name" => "Iridium plugs"}}) |> render_submit()

      assert MaintenanceItems.get(item.id).name == "Iridium plugs"
      assert render(modal) =~ "Iridium plugs"
    end

    test "deactivate and activate toggle", %{car: car, modal: modal} do
      item = item_fixture(car)
      assert has_element?(modal, ~s(button[phx-click="deactivate"][phx-value-id="#{item.id}"]))

      render_click(modal, "deactivate", %{"id" => "#{item.id}"})
      refute MaintenanceItems.get(item.id).active
      assert has_element?(modal, ~s(button[phx-click="activate"][phx-value-id="#{item.id}"]))

      render_click(modal, "activate", %{"id" => "#{item.id}"})
      assert MaintenanceItems.get(item.id).active
      assert has_element?(modal, ~s(button[phx-click="deactivate"][phx-value-id="#{item.id}"]))
    end

    test "survives another car's item being added", %{modal: modal} do
      item_fixture(car_fixture(), %{name: "Elsewhere"})
      refute render(modal) =~ "Elsewhere"
    end
  end

  describe "maintenance images modal" do
    setup %{conn: conn} do
      car = car_fixture()
      item = item_fixture(car, %{name: "Alignment"})
      sh = history_fixture(car, %{mileage: 10, maintenance_item_id: item.id})
      {_view, page} = open_page(conn, @page)
      render_click(page, "service_history", %{"id" => "#{car.id}"})
      page |> find_live_child("modal_service_history_service_history") |> render_click("maintenance_images", %{"id" => "#{sh.id}"})
      %{sh: sh, page: page, modal: find_live_child(page, "modal_maintenance_images_maintenance_images")}
    end

    # The modal copies the upload into priv/uploads, reads it back and removes it; that path is
    # fixed in the code, so the test can't point it at a tmp dir. It checks nothing is left behind.
    test "uploading an image saves it with its type, and delete removes it", %{sh: sh, modal: modal} do
      uploads = Application.app_dir(:hfg_portal_web, "priv/uploads")
      before = File.ls!(uploads)

      image = file_input(modal, "form", :image, [%{name: "receipt.png", content: @png, type: "image/png"}])
      render_upload(image, "receipt.png")

      modal |> form("form", %{"maintenance_image" => %{"name" => "Receipt"}}) |> render_submit()

      assert [img] = MaintenanceImages.list(%{service_history_id: sh.id})
      assert %{name: "Receipt", image: @png, image_content_type: "png"} = img
      assert has_element?(modal, "#image_#{img.id}", "Receipt")
      assert File.ls!(uploads) == before

      render_click(modal, "delete", %{"id" => "#{img.id}"})
      assert MaintenanceImages.get(img.id) == nil
      refute has_element?(modal, "#image_#{img.id}")
    end

    test "only takes image files", %{modal: modal} do
      image = file_input(modal, "form", :image, [%{name: "notes.txt", content: "hi", type: "text/plain"}])
      assert {:error, [[_ref, :not_accepted]]} = render_upload(image, "notes.txt")
    end

    test "saving without a file doesn't crash", %{sh: sh, modal: modal} do
      modal |> form("form", %{"maintenance_image" => %{"name" => "No file"}}) |> render_submit()
      assert MaintenanceImages.list(%{service_history_id: sh.id}) == []
      assert render(modal) =~ "Maintenance Images"
    end

    test "the image src is served", %{conn: conn, sh: sh, modal: modal} do
      {:ok, img} = MaintenanceImages.create_or_update(MaintenanceImages.new(), %{name: "x", service_history_id: sh.id, image: @png, image_content_type: "png"})
      assert render(modal) =~ ~s(src="/car_maintenance_images/#{img.id}/image")
      assert conn |> get("/car_maintenance_images/#{img.id}/image") |> response(200) == @png
    end
  end

  defp names(page) do
    page
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.find(~s(tr[phx-click="service_history"] td:first-child))
    |> Enum.map(&String.trim(Floki.text(&1)))
  end
end
