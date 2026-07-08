defmodule TaskAutomationController.QueuedItems do
  @topic "task_automation_controller:queued_items"
  @schema TaskAutomationController.Jobs.Queue
  @updated [:queued_item, :updated]
  @created [:queued_item, :created]
  @deleted [:queued_item, :deleted]

  # Include default CRUD operations from HfgPortal.Helpers.DefaultCrud
  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  #Applies sorting to a query.
  #
  ### Parameters
  #  - query: The Ecto query to sort
  #  - sort_stack: List of sort criteria with `field` and `order` keys
  defp sort_stack(query, sort_stack) when is_list(sort_stack) do
    Enum.reduce(sort_stack, query, fn(sort, query) ->
      cond do
        sort.field in [:machine_id] -> query |> order_by([qi, m],    [{^sort.order, m.name}])
        sort.field in [:job_id]     -> query |> order_by([qi, _, j], [{^sort.order, j.name}])
        sort.field in @schema.__schema__(:fields) -> 
          query |> order_by([{^sort.order, ^sort.field}])
        true -> query
      end
    end)
  end
  defp sort_stack(query, nil), do: query

  def update(), do: notify_subscribers({:ok, %{id: 1}}, @updated)

  defp filter_complete(query, true),  do: where(query, [qi], qi.status in ["completed", "failed"]) |> order_by(desc: :id)
  defp filter_complete(query, false), do: where(query, [qi], qi.status in ["unassigned", "waiting", "running"])
  defp filter_complete(query, _),     do: query

  def list(opts) do
    @schema
    |> join(:left, [qi], m    in TaskAutomationController.Jobs.Machine, on: m.id == qi.machine_id)
    |> join(:left, [qi, _], j in TaskAutomationController.Jobs.Job,     on: j.id == qi.job_id)
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    #|> where([qi], qi.status in ["unassigned", "waiting", "running"])
    |> filter_complete(Map.get(opts, :complete))
    |> Repo.all()
    |> HfgPortal.Helpers.Utility.hfg_preload(Map.get(opts, :preload, []))
  end
end
