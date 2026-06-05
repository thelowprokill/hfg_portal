defmodule CarMaintenance.MaintenanceItems do
  @topic  "car_maintenance:maintenance_items"
  @schema  CarMaintenance.Cars.MaintenanceItem
  @updated [:maintenance_item, :updated]
  @created [:maintenance_item, :created]
  @deleted [:maintenance_item, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted
  
  defp filter_car(query, car_id) when not is_nil(car_id), do: query |> where(car_id: ^car_id)
  defp filter_car(query, _car_id), do: query

  def list(opts) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> filter_car(Map.get(opts, :car_id))
    |> order_by([asc: :name])
    |> Repo.all()
    |> preload(opts)
  end
end
