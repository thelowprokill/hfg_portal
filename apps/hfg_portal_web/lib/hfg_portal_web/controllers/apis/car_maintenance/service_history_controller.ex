defmodule HfgPortalWeb.Apis.CarMaintenance.ServiceHistoryController do
  use HfgPortalWeb, :controller

  @routes [
    %{name: "service_histories", method: "GET",    function: &__MODULE__.get_service_histories/2,  description: "Get Service Histories by car"},
    %{name: "service_history",   method: "GET",    function: &__MODULE__.get_service_history/2,    description: "Get a Service History by id"},
    %{name: "service_history",   method: "PUT",    function: &__MODULE__.put_service_history/2,    description: "Add or update a cars Service History"},
    #%{name: "service_history",   method: "DELETE", function: &__MODULE__.delete_service_history/2, description: "Delete a Service History"},
  ]

  alias CarMaintenance.{
    ServiceHistories,
  }

  @preload [:maintenance_item]

  def call(%{method: method, query_params: %{"route" => route}} = conn, params) do
    Enum.find(@routes, &(&1.name == route && &1.method == method))
    |> case do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json(%{error: "Route not found"})
      %{function: fun} -> fun.(conn, params)
      _ -> 
        conn
        |> put_status(:not_found)
        |> json(%{error: "Route not found"})

    end
  end

  def get_service_histories(%{query_params: %{"car_id" => car_id} = query_params} = conn, _params) do
    service_histories = 
      ServiceHistories.list(%{
        page:     Map.get(query_params, "page"),
        per_page: Map.get(query_params, "per_page"),
        car_id:   car_id, 
        mileage:  false, 
        preload:  @preload,
      }) 
      |> Enum.map(&(%{
        id:            &1.id, 
        car_id:        &1.car_id,
        service_date:  &1.service_date, 
        mileage:       &1.mileage, 
        item:          (if &1.named_item, do: &1.name, else: &1.maintenance_item.name), 
        next_service:  (
          cond do
            !&1.named_item && &1.maintenance_item.interval_miles  -> &1.mileage + &1.maintenance_item.interval_miles
            !&1.named_item && &1.maintenance_item.interval_months -> &1.service_date |> Date.add(&1.maintenance_item.interval_months * 30)
            true -> nil
          end
        ), 
        notes:         &1.notes, 
      }))

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok, 
      date: DateTime.utc_now(),
      data: service_histories
    })
  end

  def get_service_history(%{query_params: %{"id" => id}} = conn, _params) do
    service_history = 
      id |> String.to_integer()
      |> ServiceHistories.get()
      |> ServiceHistories.preload_associations(%{preload: @preload})
      |> fn x -> %{
        id:            x.id, 
        car_id:        x.car_id,
        service_date:  x.service_date, 
        mileage:       x.mileage, 
        item:          (if x.named_item, do: x.name, else: x.maintenance_item.name), 
        next_service:  (
          cond do
            !x.named_item && x.maintenance_item.interval_miles  -> x.mileage + x.maintenance_item.interval_miles
            !x.named_item && x.maintenance_item.interval_months -> x.service_date |> Date.add(x.maintenance_item.interval_months * 30)
            true -> nil
          end
        ), 
        notes:         x.notes, 
      } end.()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok, 
      date: DateTime.utc_now(),
      data: service_history
    })
  end

  def put_service_history(%{query_params: %{"id" => id} = params} = conn, _params) do
    update_params = %{
      car_id:              Map.get(params, "car_id"),
      service_date:        Map.get(params, "service_date"),
      mileage:             Map.get(params, "mileage"),
      name:                Map.get(params, "name"),
      maintenance_item_id: Map.get(params, "item_id"),
      named_item:          Map.get(params, "name", "") != "",
      notes:               Map.get(params, "notes"),
    }
    |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
    |> Enum.into(%{})

    id |> String.to_integer()
    |> ServiceHistories.get()
    |> ServiceHistories.create_or_update(update_params)
    |> case do
      {:ok, sh} ->
        sh = ServiceHistories.preload_associations(sh, %{preload: @preload})
        conn
        |> put_status(:ok)
        |> json(%{
          response: :ok, 
          date: DateTime.utc_now(),
          data: %{
            id:            sh.id, 
            car_id:        sh.car_id,
            service_date:  sh.service_date, 
            mileage:       sh.mileage, 
            item:          (if sh.named_item, do: sh.name, else: sh.maintenance_item.name), 
            next_service:  (
              cond do
                !sh.named_item && sh.maintenance_item.interval_miles  -> sh.mileage + sh.maintenance_item.interval_miles
                !sh.named_item && sh.maintenance_item.interval_months -> sh.service_date |> Date.add(sh.maintenance_item.interval_months * 30)
                true -> nil
              end
            ), 
            notes:         sh.notes, 
          }
        })
      {:error, error} -> 
        conn
        |> put_status(:ok)
        |> json(%{
          response: :error, 
          date: DateTime.utc_now(),
          data: nil,
          error: error,
        })
    end
  end

  def put_service_history(%{query_params: params} = conn, _params) do
    update_params = %{
      car_id:              Map.get(params, "car_id"),
      service_date:        Map.get(params, "service_date"),
      mileage:             Map.get(params, "mileage"),
      name:                Map.get(params, "name"),
      maintenance_item_id: Map.get(params, "item_id"),
      named_item:          Map.get(params, "name", "") != "",
      notes:               Map.get(params, "notes"),
    }
    |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
    |> Enum.into(%{})

    ServiceHistories.new()
    |> ServiceHistories.create_or_update(update_params)
    |> case do
      {:ok, sh} ->
        sh = ServiceHistories.preload_associations(sh, %{preload: @preload})
        conn
        |> put_status(:ok)
        |> json(%{
          response: :ok, 
          date: DateTime.utc_now(),
          data: %{
            id:            sh.id, 
            car_id:        sh.car_id,
            service_date:  sh.service_date, 
            mileage:       sh.mileage, 
            item:          (if sh.named_item, do: sh.name, else: sh.maintenance_item.name), 
            next_service:  (
              cond do
                !sh.named_item && sh.maintenance_item.interval_miles  -> sh.mileage + sh.maintenance_item.interval_miles
                !sh.named_item && sh.maintenance_item.interval_months -> sh.service_date |> Date.add(sh.maintenance_item.interval_months * 30)
                true -> nil
              end
            ), 
            notes:         sh.notes, 
          }
        })
      {:error, error} -> 
        conn
        |> put_status(:ok)
        |> json(%{
          response: :error, 
          date: DateTime.utc_now(),
          data: nil,
          error: error,
        })
    end
  end

  #def delete_car(%{query_params: %{"id" => id}} = conn, _params) do
  #  id |> String.to_integer()
  #  |> Cars.delete()

  #  conn
  #  |> put_status(:ok)
  #  |> json(%{
  #    response: :ok, 
  #    date: DateTime.utc_now(),
  #    data: nil
  #  })
  #end
end
