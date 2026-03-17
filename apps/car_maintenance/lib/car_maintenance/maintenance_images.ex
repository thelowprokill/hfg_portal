defmodule CarMaintenance.MaintenanceImages do
  @topic  "car_maintenance:maintenance_images"
  @schema  CarMaintenance.Cars.MaintenanceImage
  @updated [:maintenance_image, :updated]
  @created [:maintenance_image, :created]
  @deleted [:maintenance_image, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted
  
  defp filter_service_history(query, sh_id) when not is_nil(sh_id), do: query |> where(service_history_id: ^sh_id)
  defp filter_service_history(query, _sh_id), do: query

  def list(opts) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> paginate(opts)
    |> filter_active(Map.get(opts, :active))
    |> filter_service_history(Map.get(opts, :service_history_id))
    |> order_by([asc: :name])
    |> Repo.all()
    |> preload_associations(opts)
  end
end
