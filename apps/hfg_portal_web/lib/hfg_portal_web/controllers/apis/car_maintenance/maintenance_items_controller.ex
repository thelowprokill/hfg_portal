defmodule HfgPortalWeb.Apis.CarMaintenance.MaintenanceItemsController do
  use HfgPortalWeb, :controller

  @routes [
    %{name: "maintenance_items", method: "GET", function: &__MODULE__.get_maintenance_items/2, role: :view, description: "Get Maintenance Items by car"},
  ]

  alias CarMaintenance.{
    MaintenanceItems,
  }
  alias HfgPortalWeb.Apis.CarMaintenance.AuthController

  @preload []

  def call(%{method: method, query_params: %{"route" => route}} = conn, params) do
    Enum.find(@routes, &(&1.name == route && &1.method == method))
    |> case do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json(%{error: "Route not found"})
      %{function: fun} = route_config ->
        if AuthController.authorized?(conn, route_config),
          do:   fun.(conn, params),
          else: conn |> put_status(401) |> json(%{error: "Unauthorized"})
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Route not found"})
    end
  end

  def get_maintenance_items(%{query_params: %{"car_id" => car_id}} = conn, _params) do
    maintenance_items = 
      MaintenanceItems.list(%{car_id: car_id, mileage: false, preload: @preload}) 
      |> Enum.map(&(%{
        id:              &1.id, 
        name:            &1.name,
        interval_miles:  &1.interval_miles, 
        interval_months: &1.interval_months, 
        notes:           &1.notes,
      }))

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok, 
      date: DateTime.utc_now(),
      data: maintenance_items
    })
  end
end
