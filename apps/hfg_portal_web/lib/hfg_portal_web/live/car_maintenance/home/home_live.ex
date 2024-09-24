defmodule HfgPortalWeb.CarMaintenance.Home.HomeLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.CarMaintenance.Home.Modals.{
    ChangeCar,
    ChangeMileage,
    ChangeMaintenanceItems,
    ChangeServiceHistory,
  }

  alias CarMaintenance.{
    Cars,
    ServiceHistories,
    Repo,
  }

  @preload [service_history: ServiceHistories.service_history_mileage_query()]

  defp fetch_cars(socket) do
    %{
      page:         page,
      per_page:     per_page,
      cars:         cars,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      current_user: %{id: user_id}
    } = socket.assigns

    socket |> assign(:cars, cars ++ Cars.list(
      %{
        user_id:      user_id,
        page:         page,
        per_page:     per_page,
        search_stack: search_stack,
        sort_stack:   sort_stack,
        #active:       true,
        preload:      @preload
      }
    ))
  end

  defp reload_items(socket), do: socket |> assign(:cars, []) |> fetch_cars()
  #defp fetch_reports(socket), do: socket |> assign(:reports, Reports.list(%{active: true}))

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeCar,
      changeset: Cars.new_changeset(%{created_by_id: user.id}),
      live:      false,
      user:      user,
      opts:      %{}
    } | modal_stack])
  end

  defp set_modal(socket, :edit, id) when not is_nil(id) do
    %{
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    changeset = Cars.get(id) |> Cars.change()

    socket |> assign(:modal_stack, [%Modal{
      modal:     :edit,
      id:        :edit,
      module:    ChangeCar,
      changeset: changeset,
      live:      false,
      user:      user,
      opts:      %{}
    } | modal_stack])
  end

  defp set_modal(socket, :mileage, id) when not is_nil(id) do
    %{
      cars:           cars,
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    mileage = 
      Enum.find(cars, %{service_history: %{}}, &(&1.id == id))
      |> Map.get(:service_history, %{}) 
      |> case do
        nil -> 0
        sh -> 
          Map.get(sh, :mileage, 0)
      end


    socket |> assign(:modal_stack, [%Modal{
      modal:     :mileage,
      id:        :mileage,
      module:    ChangeMileage,
      changeset: ServiceHistories.new_changeset(%{service_date: Date.utc_today(), mileage: mileage}),
      live:      false,
      user:      user,
      opts:      %{car_id: id}
    } | modal_stack])
  end

  defp set_modal(socket, :maintenance_items, id) when not is_nil(id) do
    %{
      cars:           cars,
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    car = 
      cars
      |> Enum.find(&(&1.id == id))

    socket |> assign(:modal_stack, [%Modal{
      modal:     :maintenance_items,
      id:        :maintenance_items,
      module:    ChangeMaintenanceItems,
      live:      true,
      user:      user,
      opts:      %{car_id: id, car_name: car.name}
    } | modal_stack])
  end

  defp set_modal(socket, :service_history, id) when not is_nil(id) do
    %{
      cars:           cars,
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    car = 
      cars
      |> Enum.find(&(&1.id == id))

    socket |> assign(:modal_stack, [%Modal{
      modal:     :service_history,
      id:        :service_history,
      module:    ChangeServiceHistory,
      live:      true,
      user:      user,
      opts:      %{car: car}
    } | modal_stack])
  end
  #defp set_modal(socket, :fixed_timesheets, id) when not is_nil(id) do
  #  %{
  #    fixed_projects: projects,
  #    modal_stack:    modal_stack,
  #    current_user:   user
  #  } = socket.assigns

  #  socket |> assign(:modal_stack, [%Modal{
  #    modal:     :timesheets,
  #    id:        :timesheets,
  #    module:    ChangeTimesheets,
  #    live:      true,
  #    user:      user,
  #    opts:      %{
  #      fixed_project_id: id,
  #      project_name:     Enum.find(projects, &(&1.id == id)) |> Map.get(:name),
  #      user_id:          user.id
  #    }
  #  } | modal_stack])
  #end

  #defp set_modal(socket, :timesheets, id) when not is_nil(id) do
  #  %{
  #    projects:          projects,
  #    favorite_projects: favorite_projects,
  #    modal_stack:       modal_stack,
  #    current_user:      user
  #  } = socket.assigns

  #  socket |> assign(:modal_stack, [%Modal{
  #    modal:     :timesheets,
  #    id:        :timesheets,
  #    module:    ChangeTimesheets,
  #    live:      true,
  #    user:      user,
  #    opts:      %{
  #      project_id:   id,
  #      project_name: Enum.find(projects, Enum.find(favorite_projects, &(&1.id == id)), &(&1.id == id)) |> Map.get(:name),
  #      user_id:      user.id
  #    }
  #  } | modal_stack])
  #end

  defp set_modal(socket, :reports, id) when not is_nil(id) do
    %{ 
      modal_stack: modal_stack,
      reports:     reports
    } = socket.assigns
    socket
    |> assign(:modal_stack, [%Modal{
      modal:  :report,
      id:     :report,
      opts:   %{report: Enum.find(reports, &(&1.id == id)) |> Reports.decorate()},
    } | modal_stack])
  end

  defp set_modal(socket, :reports, _) do
    %{ 
      modal_stack: modal_stack,
      reports:     reports
    } = socket.assigns

    socket
    |> assign(:modal_stack, 
      cond do
        length(reports) == 1 ->
          [%Modal{
            modal:  :report,
            id:     :report,
            opts:   %{report: Enum.at(reports, 0) |> Reports.decorate()},
          } | modal_stack]
        length(reports) > 1 ->
          [ %Modal{
            modal:  :pick_reports,
            id:     :pick_reports,
            module: nil
          } | modal_stack]
        true -> 
          modal_stack
      end)
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Cars.subscribe()
      ServiceHistories.subscribe()
      #Reports.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Car Maintenance", "Home")
    #|> fetch_user_role()
    |> assign(:session,       %{})
    |> assign(:page,          0)
    |> assign(:per_page,      50)
    |> assign(:cars,      [])
    |> assign(:reports,       [])
    |> assign(:modal_stack,   [])
    |> assign(:capacity,      %{})
    |> assign(:search_map,    %{})
    |> assign(:search_stack,  [])
    |> assign(:sort_stack,    [])
    |> handle_params(session)
    |> fetch_cars()
    #|> fetch_reports()
    |> res(:ok)
  end

  defp handle_params(socket, %{"search" => _search} = session) do 
    socket
    |> search_handle_params(session)
    |> handle_params(session |> Map.delete("search"))
  end

  defp handle_params(socket, %{"sort" => _sort} = session) do 
    socket
    |> sort_handle_params(session)
    |> handle_params(session |> Map.delete("sort"))
  end

  defp handle_params(socket, %{"app" => app} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "app", app))
    |> handle_params(session |> Map.delete("app"))
  end
  defp handle_params(socket, %{"page" => page} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "page", page))
    |> handle_params(session |> Map.delete("page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "admin", admin))
    |> handle_params(session |> Map.delete("admin"))
  end
  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:service_history, _], service_history}, socket) do
    socket
    |> assign(:cars, Enum.map(socket.assigns.cars, &(if &1.id == service_history.car_id, do: &1.id |> Cars.get() |> Repo.preload(@preload), else: &1)))
    |> res()
  end

  @impl true
  def handle_info({[:car, :created], car}, socket) do
    socket
    |> assign(:cars, [car |> Repo.preload(@preload) | socket.assigns.cars])
    |> res()
  end
  @impl true
  def handle_info({[:car, :updated], car}, socket) do
    socket
    |> assign(:cars, Enum.map(socket.assigns.cars, &(if &1.id == car.id, do: car |> Repo.preload(@preload), else: &1)))
    |> res()
  end
  @impl true
  def handle_info({[:car, :deleted], car}, socket) do
    socket
    |> assign(:cars, Enum.reject(socket.assigns.cars, &(&1.id == car.id)))
    |> res()
  end
  
  @impl true
  def handle_info({[:report, :created], report}, socket) do
    socket
    |> assign(:reports, [report | socket.assigns.reports])
    |> res()
  end
  @impl true
  def handle_info({[:report, :updated], report}, socket) do
    %{reports: reports} = socket.assigns
    socket
    |> assign(:reports, cond do
      Enum.any?(reports, &(&1.id == report.id)) -> Enum.map(reports, &(if &1.id == report.id, do: report, else: &1))
      true -> [report | reports]
    end |> Enum.filter(&(&1.active)))
    |> res()
  end
  @impl true
  def handle_info({[:report, :deleted], report}, socket) do
    socket
    |> assign(:reports, Enum.reject(socket.assigns.reports, &(&1.id == report.id)))
    |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("maintenance_items", %{"id" => id}, socket), do: socket |> set_modal(:maintenance_items, id |> String.to_integer) |> res()

  @impl true
  def handle_event("service_history", %{"id" => id}, socket), do: socket |> set_modal(:service_history, id |> String.to_integer) |> res()

  @impl true
  def handle_event("mileage", %{"id" => id}, socket), do: socket |> set_modal(:mileage, id |> String.to_integer) |> res()

  @impl true
  def handle_event("add_new", _, socket), do: socket |> set_modal(:new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: socket |> set_modal(:edit, id |> String.to_integer) |> res()

  @impl true
  def handle_event("reports", %{"id" => id}, socket), do: socket |> set_modal(:reports, id |> String.to_integer) |> res()

  @impl true
  def handle_event("reports", _, socket), do: socket |> set_modal(:reports) |> res()

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_cars()
    |> res()
  end

  @impl true
  def handle_event("sort", params, socket), do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket), do: socket |> search_reset_filter(field) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", _, socket), do: socket |> search_reset_filter() |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket), do: socket |> search(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"field" => _} = params, socket), do: search(socket, params) |> res()
  @impl true
  def handle_event("hide_filter", _, socket), do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
