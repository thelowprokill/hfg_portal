defmodule CarMaintenance.ServiceHistories do
  @topic "car_maintenance:service_histories"
  @schema CarMaintenance.Cars.ServiceHistory
  @updated [:service_history, :updated]
  @created [:service_history, :created]
  @deleted [:service_history, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def service_history_mileage_query() do
    @schema
    |> join(:left, [sh], c in CarMaintenance.Cars.Car, on: c.id == sh.car_id)
    |> group_by([sh], [sh.car_id])
    |> select([sh], %{car_id: sh.car_id, mileage: max(sh.mileage), service_history: count(sh.id)})
  end

  def service_history_query() do
    @schema
    |> join(:left, [sh], c in CarMaintenance.Cars.Car, on: c.id == sh.car_id)
    |> group_by([sh], [sh.car_id, sh.maintenance_item_id])
    #|> order_by([sh], [desc: sh.service_date])
    |> select([sh], %{car_id: sh.car_id, service_date: max(sh.service_date), mileage: max(sh.mileage)})
  end

  defp filter_car(query, car_id) when not is_nil(car_id), do: query |> where(car_id: ^car_id)
  defp filter_car(query, _car_id), do: query

  defp filter_mileage(query, true), do: query |> where([sh], is_nil(sh.name) and is_nil(sh.maintenance_item_id))
  defp filter_mileage(query, false), do: query |> where([sh], not is_nil(sh.name) or not is_nil(sh.maintenance_item_id))
  defp filter_mileage(query, _mileage), do: query

  def list(opts) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> paginate(opts)
    |> order_by([i], [desc: i.mileage, desc: i.service_date, desc: i.id])
    |> filter_car(Map.get(opts, :car_id))
    |> filter_mileage(Map.get(opts, :mileage))
    |> Repo.all()
    |> preload_associations(opts)
  end
end
