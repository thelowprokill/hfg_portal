defmodule CarMaintenance.ServiceHistories do
  import Ecto.Query
  import HfgPortal.Helpers.Utility

  alias CarMaintenance.Repo

  @topic "car_maintenance:service_histories"
  @schema CarMaintenance.Cars.ServiceHistory
  @updated [:service_history, :updated]
  @created [:service_history, :created]
  @deleted [:service_history, :deleted]

  def subscribe(),     do: Phoenix.PubSub.subscribe(HfgPortal.PubSub,   @topic)
  def subscribe(id),   do: Phoenix.PubSub.subscribe(HfgPortal.PubSub,   "#{@topic}:#{id}")
  def unsubscribe(),   do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, @topic)
  def unsubscribe(id), do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, "#{@topic}:#{id}")
  defp notify_subscribers({:ok, result}, event) do
    Phoenix.PubSub.broadcast(HfgPortal.PubSub, @topic, {event, result})
    Phoenix.PubSub.broadcast(HfgPortal.PubSub, "#{@topic}:#{result.id}", {event, result})
    {:ok, result}
  end
  defp notify_subscribers({:error, reason}, _event), do: {:error, reason}


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

  defp search_stack(query, search_stack) when is_list(search_stack) do
    Enum.reduce(search_stack, query, fn(search, query) ->
      cond do
        search.field in @schema.__schema__(:fields) -> query |> where([r], like(field(r, ^search.field), ^"%#{search.val}%") or ^search.val == "")
        true -> query
      end
    end)
  end
  defp search_stack(query, nil), do: query

  defp sort_stack(query, sort_stack) when is_list(sort_stack) do
    Enum.reduce(sort_stack, query, fn(sort, query) ->
      cond do
        sort.field in @schema.__schema__(:fields) -> query |> order_by([{^sort.order, ^sort.field}])
        true -> query
      end
    end)
  end
  defp sort_stack(query, nil), do: query

  #defp filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
  #defp filter_active(query, _active), do: query

  defp filter_car(query, car_id) when not is_nil(car_id), do: query |> where(car_id: ^car_id)
  defp filter_car(query, _car_id), do: query

  defp filter_mileage(query, true), do: query |> where([sh], is_nil(sh.name) and is_nil(sh.maintenance_item_id))
  defp filter_mileage(query, false), do: query |> where([sh], not is_nil(sh.name) or not is_nil(sh.maintenance_item_id))
  defp filter_mileage(query, _mileage), do: query

  #defp filter_dates(query, dates) when not is_nil(dates) do
  #  query
  #  |> where([c], c.monday in ^dates)
  #end
  #defp filter_dates(query, _dates), do: query

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> order_by([i], [desc: i.mileage, desc: i.service_date, desc: i.id])
    |> filter_car(Map.get(opts, :car_id))
    |> filter_mileage(Map.get(opts, :mileage))
    |> Repo.all()
    |> bnw_preload(Map.get(opts, :preload, []))
  end
  def preload(val, opts \\ %{}), do: bnw_preload(val, Map.get(opts, :preload, []))

  def create_or_update(%@schema{} = item, attrs \\ %{}) do
    new_item = is_nil(item.id)
    item
    |> change(attrs)
    |> Repo.insert_or_update()
    |> notify_subscribers(if new_item, do: @created, else: @updated)
  end

  def get(id), do: Repo.get(@schema, id)
  def new(), do: %@schema{}
  def new_changeset(attrs \\ %{}), do: new() |> change(attrs)
  def change(%@schema{} = item, attrs \\ %{}), do: @schema.changeset(item, attrs)
  def delete(%@schema{} = item), do: item |> Repo.delete() |> notify_subscribers(@deleted)
  def delete(id), do: get(id) |> delete()

  def activate(%@schema{} = item),   do: item |> change(%{active: true})  |> Repo.update() |> notify_subscribers(@updated)
  def activate(id), do: get(id) |> activate()
  def deactivate(%@schema{} = item), do: item |> change(%{active: false}) |> Repo.update() |> notify_subscribers(@updated)
  def deactivate(id), do: get(id) |> deactivate()
end
