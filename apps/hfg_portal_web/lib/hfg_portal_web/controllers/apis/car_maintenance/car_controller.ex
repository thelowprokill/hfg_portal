defmodule HfgPortalWeb.Apis.CarMaintenance.CarController do
  use HfgPortalWeb, :controller

  @routes [
    %{name: "cars", method: "GET",    function: &__MODULE__.get_cars/2,   description: "List all cars"},
    %{name: "car",  method: "GET",    function: &__MODULE__.get_car/2,    description: "Get a car by id"},
    %{name: "car",  method: "PUT",    function: &__MODULE__.put_car/2,    description: "Add or update a car"},
    %{name: "car",  method: "DELETE", function: &__MODULE__.delete_car/2, description: "Delete a car"},
  ]

  alias CarMaintenance.{
    Cars,
    ServiceHistories,
  }

  @preload [service_history: ServiceHistories.service_history_mileage_query()]

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

  def get_cars(%{query_params: query_params} = conn, _params) do
    cars = 
      Cars.list(%{
        page:     Map.get(query_params, "page"),
        per_page: Map.get(query_params, "per_page"),
        preload:  @preload,
      }) 
      |> Enum.map(&(%{
        id:            &1.id, 
        name:          &1.name, 
        year:          &1.year, 
        make:          &1.make, 
        model:         &1.model, 
        license_plate: &1.license_plate, 
        vin:           &1.vin,
        mileage:       (if &1.service_history, do: &1.service_history.mileage |> Number.Delimit.number_to_delimited(precision: 0), else: nil)
      }))

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok, 
      date: DateTime.utc_now(),
      data: cars
    })
  end

  def get_car(%{query_params: %{"id" => id}} = conn, _params) do
    car = 
      id |> String.to_integer()
      |> Cars.get()
      |> Cars.preload(%{preload: @preload})
      |> fn x -> %{
        id:            x.id, 
        name:          x.name, 
        year:          x.year, 
        make:          x.make, 
        model:         x.model, 
        license_plate: x.license_plate, 
        vin:           x.vin
      } end.()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok, 
      date: DateTime.utc_now(),
      data: car
    })
  end

  def put_car(%{query_params: %{"id" => id} = params} = conn, _params) do
    update_params = %{
      name:          Map.get(params, "name"),
      year:          Map.get(params, "year"),
      make:          Map.get(params, "make"),
      model:         Map.get(params, "model"),
      license_plate: Map.get(params, "license_plate"),
      vin:           Map.get(params, "vin"),
    }
    |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
    |> Enum.into(%{})

    id |> String.to_integer()
    |> Cars.get()
    |> Cars.create_or_update(update_params)
    |> case do
      {:ok, car} ->
        conn
        |> put_status(:ok)
        |> json(%{
          response: :ok, 
          date: DateTime.utc_now(),
          data: %{
            id:            car.id, 
            name:          car.name, 
            year:          car.year, 
            make:          car.make, 
            model:         car.model, 
            license_plate: car.license_plate, 
            vin:           car.vin
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

  def put_car(%{query_params: params} = conn, _params) do
    update_params = %{
      name:          Map.get(params, "name"),
      year:          Map.get(params, "year"),
      make:          Map.get(params, "make"),
      model:         Map.get(params, "model"),
      license_plate: Map.get(params, "license_plate"),
      vin:           Map.get(params, "vin"),
    }
    |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
    |> Enum.into(%{})

    Cars.new()
    |> Cars.create_or_update(update_params)
    |> case do
      {:ok, car} ->
        conn
        |> put_status(:ok)
        |> json(%{
          response: :ok, 
          date: DateTime.utc_now(),
          data: %{
            id:            car.id, 
            name:          car.name, 
            year:          car.year, 
            make:          car.make, 
            model:         car.model, 
            license_plate: car.license_plate, 
            vin:           car.vin
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

  def delete_car(%{query_params: %{"id" => id}} = conn, _params) do
    id |> String.to_integer()
    |> Cars.delete()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok, 
      date: DateTime.utc_now(),
      data: nil
    })
  end
end
