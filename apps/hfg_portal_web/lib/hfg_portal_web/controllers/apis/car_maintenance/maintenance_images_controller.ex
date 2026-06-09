defmodule HfgPortalWeb.Apis.CarMaintenance.MaintenanceImagesController do
  use HfgPortalWeb, :controller

  @routes [
    %{name: "maintenance_images", method: "GET",    function: &__MODULE__.get_maintenance_images/2,   description: "Get Maintenance Images by car"},
    %{name: "maintenance_image",  method: "GET",    function: &__MODULE__.get_maintenance_image/2,    description: "Get Maintenance Image by id"},
    %{name: "maintenance_image",  method: "PUT",    function: &__MODULE__.put_maintenance_image/2,    description: "Add or update an image"},
    %{name: "maintenance_image",  method: "DELETE", function: &__MODULE__.delete_maintenance_image/2, description: "Delete an image"},
  ]

  alias CarMaintenance.{
    MaintenanceImages,
  }

  @preload []

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

  def get_maintenance_images(%{query_params: %{"service_history_id" => service_history_id}} = conn, _params) do
    maintenance_images = 
      MaintenanceImages.list(%{service_history_id: service_history_id, preload: @preload}) 
      |> Enum.map(fn x -> 
        base64_image = Base.encode64(x.image)

        %{
          id:                 x.id, 
          name:               x.name,
          image:              "data:#{x.image_content_type};base64,#{base64_image}",
          image_content_type: x.image_content_type
        }
      end)

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok, 
      date: DateTime.utc_now(),
      data: maintenance_images
    })
  end

  def get_maintenance_image(%{query_params: %{"id" => id}} = conn, _params) do
    maintenance_image = 
      id |> String.to_integer()
      |> MaintenanceImages.get()
      |> MaintenanceImages.preload(%{preload: @preload})
      |> fn x -> 
        base64_image = Base.encode64(x.image)
        %{
          id:                 x.id, 
          name:               x.name,
          #image:              x.image,
          image:              "data:#{x.image_content_type};base64,#{base64_image}",
          image_content_type: x.image_content_type
        } 
      end.()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok, 
      date: DateTime.utc_now(),
      data: maintenance_image
    })
  end

  def put_maintenance_image(%{query_params: query_params, body_params: body_params} = conn, _params) do
    upload = Map.get(body_params, "image")
    binary_data = File.read!(upload.path)
    File.rm(upload.path)
  
    update_params = %{
      "name"               => Map.get(body_params, "name"),
      "image"              => binary_data,
      "image_content_type" => Map.get(body_params, "image_content_type"),
      "service_history_id" => Map.get(body_params, "service_history_id")
    }
  
    MaintenanceImages.new()
    |> MaintenanceImages.create_or_update(update_params)
    |> case do
      {:ok, mi} -> 
        # ... success response
        base64_image = Base.encode64(mi.image)
        conn
        |> put_status(:ok)
        |> json(%{
          response: :ok, 
          date: DateTime.utc_now(),
          data: %{
            id:                 mi.id, 
            name:               mi.name, 
            image:              "data:#{mi.image_content_type};base64,#{base64_image}",
            image_content_type: mi.image_content_type, 
          }
        })
      {:error, error} -> 
        # ... error response
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

  def delete_maintenance_image(%{query_params: %{"id" => id}} = conn, _params) do
    id |> String.to_integer()
    |> MaintenanceImages.delete()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok, 
      date: DateTime.utc_now(),
      data: nil
    })
  end
end
