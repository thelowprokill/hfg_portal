defmodule BnwPortalWeb.AdminLogs.Home.HomeLive do
  use BnwPortalWeb, :live_view

  alias BnwPortalWeb.AdminLogs.Home.Modals.{
    ChangeSections
  }

  alias AdminLogs.{
    HiddenSections,
    AdminLogs,
    MedCoolerDatas,
    MedCoolerSensors,
    WeatherStationDatas,
    WeatherStationSensors,
    TurnkeyUpdates,
    PythonScripts,
  }

  defp fetch_hidden_sections(socket) do
    socket
    |> assign(:hidden_sections, HiddenSections.list(%{user_id: socket.assigns.current_user.id}))
  end

  defp fetch_med_cooler_sensors(socket) do
    %{hidden_sections: hidden_sections} = socket.assigns

    cond do
      Enum.any?(hidden_sections, &(&1.section == "med_coolers")) -> socket
      true ->
        socket
        |> assign(:med_cooler_sensors, MedCoolerSensors.list())
    end
  end

  defp fetch_med_cooler_data(socket) do
    %{
      hidden_sections:    hidden_sections,
      med_cooler_sensors: med_cooler_sensors
    } = socket.assigns

    cond do
      Enum.any?(hidden_sections, &(&1.section == "med_coolers")) -> socket
      true ->
        socket
        |> assign_async(:med_cooler, fn -> {:ok, %{
          med_cooler:
            MedCoolerDatas.list(%{
              search_stack: [%{val: round_to(DateTime.utc_now() |> DateTime.add(-1, :day)), field: :inserted_at}]
            })
            |> calc_med_cooler_charts(med_cooler_sensors)
        }} end)
    end
  end

  defp calc_med_cooler_charts(med_cooler_data, med_cooler_sensors) do
    time = round_to(DateTime.utc_now() |> DateTime.add(-1, :day))
    Enum.map(med_cooler_sensors, fn sensor ->
      {status, alarm} = 
        Enum.map(0..143, fn x ->
          t = time |> DateTime.add(x * 10, :minute)
          Enum.find(med_cooler_data, &(&1.sensor_id == sensor.id && &1.inserted_at |> DateTime.from_naive!("Etc/UTC") |> round_to == t))
          |> case do
            nil  -> {false, -1}
            data -> {true,  data.status_id}
          end
        end)
        |> Enum.unzip()

      sensor
      |> Map.put(:status, status)
      |> Map.put(:alarm,  alarm)
    end)
  end

  defp fetch_weather_station_sensors(socket) do
    %{hidden_sections: hidden_sections} = socket.assigns

    cond do
      Enum.any?(hidden_sections, &(&1.section == "weather_stations")) -> socket
      true ->
        socket
        |> assign(:weather_station_sensors, WeatherStationSensors.list())
    end
  end

  defp fetch_weather_station_data(socket) do
    %{
      hidden_sections:         hidden_sections,
      weather_station_sensors: weather_station_sensors
    } = socket.assigns

    cond do
      Enum.any?(hidden_sections, &(&1.section == "weather_stations")) -> socket
      true ->
        socket
        |> assign_async(:weather_station, fn -> {:ok, %{
          weather_station:
            WeatherStationDatas.list(%{
              search_stack: [%{val: round_to(DateTime.utc_now() |> DateTime.add(-1, :day)), field: :inserted_at}]
            })
            |> calc_weather_station_charts(weather_station_sensors)
        }} end)
    end
  end

  defp calc_weather_station_charts(weather_station_data, weather_station_sensors) do
    time = round_to(DateTime.utc_now() |> DateTime.add(-1, :day))
    weather_station_sensors = Enum.map(weather_station_sensors, fn sensor ->
      status = Enum.map(0..143, fn x ->
        t = time |> DateTime.add(x * 10, :minute)
        Enum.any?(weather_station_data, &(&1.sensor_id == sensor.id && &1.inserted_at |> DateTime.from_naive!("Etc/UTC") |> round_to == t))
      end)

      Map.put(sensor, :status, status)
    end)
  end

  defp fetch_turnkey_update_tables(socket) do
    %{hidden_sections: hidden_sections} = socket.assigns

    cond do
      Enum.any?(hidden_sections, &(&1.section == "turnkey_updates")) -> socket
      true ->
        socket
        |> assign(:turnkey_update_tables, TurnkeyUpdates.list_tables())
    end
  end

  defp fetch_turnkey_update_data(socket) do
    %{
      hidden_sections:       hidden_sections,
      turnkey_update_tables: turnkey_update_tables
    } = socket.assigns

    cond do
      Enum.any?(hidden_sections, &(&1.section == "turnkey_updates")) -> socket
      true ->
        socket
        |> assign_async(:turnkey_update, fn -> {:ok, %{
          turnkey_update: 
            TurnkeyUpdates.list(%{
              search_stack: [%{val: round_to(DateTime.utc_now() |> DateTime.add(-1, :day)), field: :inserted_at}]
            })
            |> calc_turnkey_update_charts(turnkey_update_tables)
        }} end)
    end
  end

  defp calc_turnkey_update_charts(turnkey_update_data, turnkey_update_tables) do
    dt = DateTime.utc_now() |> DateTime.add(-1, :day)
    Enum.map(turnkey_update_tables, fn table ->
      count = if table.table in ["reconc"], do: 24, else: 144
      duration = cond do
        table.table in ["reconc"] -> 1
        true -> 10
      end
      rt = cond do
        table.table in ["reconc"] -> :hour
        true -> :minute
      end
      dt = dt |> round_to(duration, rt)
      status = Enum.map(0..(count - 1), fn x ->
        dt = dt |> DateTime.add(x * duration, rt)
        time = dt |> DateTime.to_time
        cond do
          Time.after?(time, ~T[02:00:00]) && Time.before?(time, ~T[13:00:00]) -> -1
          true -> 
            turnkey_update_data
            |> Enum.find(%{errors: 1}, &(&1.table == table.table && &1.errors == 0 && &1.inserted_at |> DateTime.from_naive!("Etc/UTC") |> round_to(duration, rt) == dt))
            |> Map.get(:errors)
        end
      end)
      Map.put(table, :status, status)
    end)
  end

  defp fetch_python_scripts(socket) do
    %{hidden_sections: hidden_sections} = socket.assigns

    cond do
      Enum.any?(hidden_sections, &(&1.section == "python_scripts")) -> socket
      true ->
        socket
        |> assign(:python_scripts, PythonScripts.list_scripts())
    end
  end

  defp fetch_python_script_data(socket) do
    %{
      hidden_sections: hidden_sections,
      python_scripts:  python_scripts
    } = socket.assigns

    cond do
      Enum.any?(hidden_sections, &(&1.section == "python_scripts")) -> socket
      true ->
        socket
        |> assign_async(:python_script, fn -> {:ok, %{
          python_script:
            PythonScripts.list(%{
              search_stack: [%{val: round_to(DateTime.utc_now() |> DateTime.add(-1, :day)), field: :inserted_at}]
            })
            |> calc_python_script_charts(python_scripts)
        }} end)
    end
  end

  defp calc_python_script_charts(python_script_data, python_scripts) do
    python_scripts = Enum.map(python_scripts, fn script ->
      rt = script.run_type |> String.to_atom
      dt = DateTime.utc_now() |> DateTime.add(-1 * (script.duration * (script.count - (if rt == :day, do: 1, else: 0))), rt) |> round_to(script.duration, rt, script.off_end)
      status = Enum.map(0..(script.count - 1), fn x ->
        dt = dt |> DateTime.add(x * script.duration, rt)
        time = dt |> DateTime.to_time
        cond do
          script.off_start 
          && script.off_end 
          && Time.after?(time, Time.from_iso8601!("#{"#{script.off_start}" |> String.pad_leading(2, "0")}:00:00")) 
          && Time.before?(time, Time.from_iso8601!("#{"#{script.off_end}" |> String.pad_leading(2, "0")}:00:00")) -> -1
          true -> 
            python_script_data
            |> Enum.find(%{errors: 1}, fn x -> 
              x.python_script_id == script.id && x.inserted_at |> DateTime.from_naive!("Etc/UTC") |> round_to(script.duration, rt, script.off_end) == dt 
              end)
            |> Map.get(:errors)
        end
      end)

      Map.put(script, :status, status)
    end)
  end

  defp round_to(datetime, time \\ 10, type \\ :minute, offset \\ 0)
  defp round_to(datetime, day,    :day, _) do 
    t_hour   = datetime.hour
    t_minute = datetime.minute
    t_second = datetime.second
    
    total_seconds_to_remove = t_hour * 3600 + t_minute * 60 + t_second

    # Subtract extra minutes and seconds
    DateTime.add(datetime, -total_seconds_to_remove, :second) |> DateTime.truncate(:second)
  end
  defp round_to(datetime, hour,   :hour, nil), do: round_to(datetime, hour, :hour, 0)
  defp round_to(datetime, hour,   :hour, offset) do 

    t_hour   = datetime.hour
    t_minute = datetime.minute
    t_second = datetime.second

    offset = rem(offset, hour)
    adjusted_hour = (t_hour + 24 - offset) |> rem(24)

    nearest_multiple = trunc(adjusted_hour / hour) * hour + offset |> rem(24)

    extra_minutes = rem(t_minute, 60) # Calculate remainder after dividing by 10
    
    total_seconds_to_remove = extra_minutes * 60 + t_second

    datetime
    |> DateTime.add(-1 * (t_hour - nearest_multiple), :hour)
    |> DateTime.add(-total_seconds_to_remove, :second)
    |> DateTime.truncate(:second)
  end
  defp round_to(datetime, minute, :minute, _) do
    t_minute = datetime.minute
    t_second = datetime.second
    
    extra_minutes = rem(t_minute, minute) # Calculate remainder after dividing by 10
    
    total_seconds_to_remove = extra_minutes * 60 + t_second

    # Subtract extra minutes and seconds
    DateTime.add(datetime, -total_seconds_to_remove, :second) |> DateTime.truncate(:second)
  end

  defp save_charts(socket) do
    %{
      med_cooler:      med_cooler,
      weather_station: weather_station,
      turnkey_update:  turnkey_update,
      python_script:   python_script,
    } = socket.assigns

    socket
    |> assign(:med_cooler_saved,      med_cooler)
    |> assign(:weather_station_saved, weather_station)
    |> assign(:turnkey_update_saved,  turnkey_update)
    |> assign(:python_script_saved,   python_script)
  end

  defp refresh_charts(socket) do
    socket
    |> save_charts()
    |> fetch_med_cooler_sensors()
    |> fetch_med_cooler_data()
    |> fetch_weather_station_sensors()
    |> fetch_weather_station_data()
    |> fetch_turnkey_update_tables()
    |> fetch_turnkey_update_data()
    |> fetch_python_scripts()
    |> fetch_python_script_data()
  end

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :hidden_sections, _) do
    %{modal_stack: modal_stack} = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:     :hidden_sections,
      module:    ChangeSections,
      live:      true,
      user:      socket.assigns.current_user,
      id:        :id,
      opts:      %{},
    }))
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      AdminLogs.subscribe()
      HiddenSections.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Admin Logs", "Home")
    |> assign(:anim,                    %Phoenix.LiveView.AsyncResult{})
    |> assign(:hidden_sections,         [])
    |> assign(:med_cooler_sensors,      [])
    |> assign(:med_cooler_saved,        %Phoenix.LiveView.AsyncResult{})
    |> assign(:med_cooler,              %Phoenix.LiveView.AsyncResult{})
    |> assign(:weather_station_sensors, [])
    |> assign(:weather_station_saved,   %Phoenix.LiveView.AsyncResult{})
    |> assign(:weather_station,         %Phoenix.LiveView.AsyncResult{})
    |> assign(:turnkey_update_tables,   [])
    |> assign(:turnkey_update_saved,    %Phoenix.LiveView.AsyncResult{})
    |> assign(:turnkey_update,          %Phoenix.LiveView.AsyncResult{})
    |> assign(:python_scripts,          [])
    |> assign(:python_scripts_saved,    %Phoenix.LiveView.AsyncResult{})
    |> assign(:python_script,           %Phoenix.LiveView.AsyncResult{})
    |> assign(:session,       %{})
    |> assign(:page,          0)
    |> assign(:per_page,      50)
    |> assign(:details,       [])
    |> assign(:reports,       [])
    |> assign(:modal_stack,   [])
    |> assign(:search_map,    %{})
    |> assign(:search_stack,  [])
    |> assign(:sort_stack,    [])
    |> fetch_hidden_sections()
    |> refresh_charts()
    |> handle_params(session)
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
  def handle_info({[:admin_logs, :updated], _}, socket), do:
    socket 
    |> refresh_charts() 
    |> assign_async(:anim, fn -> 
      :timer.sleep(1000)
      {:ok, %{anim: false}}
    end)
    |> res()

  @impl true
  def handle_info({[:hidden_section, :created], item}, socket) do
    %{hidden_sections: hidden_sections} = socket.assigns
    socket |> assign(:hidden_sections, [item | hidden_sections]) |> res()
  end
  @impl true
  def handle_info({[:hidden_section, :deleted], item}, socket) do
    %{hidden_sections: hidden_sections} = socket.assigns
    socket |> assign(:hidden_sections, Enum.reject(hidden_sections, &(&1.id == item.id))) |> refresh_charts() |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("hidden_sections", _, socket), do: set_modal(socket, :hidden_sections, :show) |> res()

  @impl true
  def handle_event("refresh", _, socket), do:
    socket 
    |> refresh_charts() 
    |> assign_async(:anim, fn -> 
      :timer.sleep(1000)
      {:ok, %{anim: false}}
    end)
    |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__);
    socket |> res()
  end
end
