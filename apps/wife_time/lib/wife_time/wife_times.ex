defmodule WifeTime.WifeTimes do
  @topic "wife_time:wife_times"
  @schema WifeTime.WifeTimes.WifeTime
  @updated [:wife_time, :updated]
  @created [:wife_time, :created]
  @deleted [:wife_time, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def get_max_date() do
    @schema
    |> order_by(desc: :entry_date)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> Date.utc_today()
      item -> item.entry_date
    end
  end

  #import Ecto.Query
  #import HfgPortal.Helpers.Utility

  #alias WifeTime.Repo

  #def subscribe(),     do: Phoenix.PubSub.subscribe(HfgPortal.PubSub,   @topic)
  #def subscribe(id),   do: Phoenix.PubSub.subscribe(HfgPortal.PubSub,   "#{@topic}:#{id}")
  #def unsubscribe(),   do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, @topic)
  #def unsubscribe(id), do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, "#{@topic}:#{id}")
  #defp notify_subscribers({:ok, result}, event) do
  #  Phoenix.PubSub.broadcast(HfgPortal.PubSub, @topic, {event, result})
  #  Phoenix.PubSub.broadcast(HfgPortal.PubSub, "#{@topic}:#{result.id}", {event, result})
  #  {:ok, result}
  #end
  #defp notify_subscribers({:error, reason}, _event), do: {:error, reason}

  #def get_max_date() do
  #  @schema
  #  |> order_by(desc: :entry_date)
  #  |> limit(1)
  #  |> Repo.one()
  #  |> case do
  #    nil -> Date.utc_today()
  #    item -> item.entry_date
  #  end
  #end


  #defp search_stack(query, search_stack) when is_list(search_stack) do
  #  Enum.reduce(search_stack, query, fn(search, query) ->
  #    cond do
  #      search.field in @schema.__schema__(:fields) -> query |> where([r], like(field(r, ^search.field), ^"%#{search.val}%") or ^search.val == "")
  #      true -> query
  #    end
  #  end)
  #end
  #defp search_stack(query, nil), do: query

  #defp sort_stack(query, sort_stack) when is_list(sort_stack) do
  #  Enum.reduce(sort_stack, query, fn(sort, query) ->
  #    cond do
  #      sort.field in @schema.__schema__(:fields) -> query |> order_by([{^sort.order, ^sort.field}])
  #      true -> query
  #    end
  #  end)
  #end
  #defp sort_stack(query, nil), do: query

  #defp filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
  #defp filter_active(query, _active), do: query

  #def list(opts \\ %{}) do
  #  @schema
  #  |> search_stack(Map.get(opts, :search_stack))
  #  |> sort_stack(Map.get(opts, :sort_stack))
  #  |> order_by([wt], desc: wt.entry_date)
  #  |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
  #  |> filter_active(Map.get(opts, :active))
  #  |> Repo.all()
  #  |> bnw_preload(Map.get(opts, :preload, []))
  #end
  #def preload(val, opts \\ %{}), do: bnw_preload(val, Map.get(opts, :preload, []))

  #def create_or_update(%@schema{} = item, attrs \\ %{}) do
  #  new_item = is_nil(item.id)
  #  item
  #  |> change(attrs)
  #  |> Repo.insert_or_update()
  #  |> notify_subscribers(if new_item, do: @created, else: @updated)
  #end

  #def get(id), do: Repo.get(@schema, id)
  #def new(), do: %@schema{}
  #def new_changeset(attrs \\ %{}), do: new() |> change(attrs)
  #def change(%@schema{} = item, attrs \\ %{}), do: @schema.changeset(item, attrs)
  #def delete(%@schema{} = item), do: item |> Repo.delete() |> notify_subscribers(@deleted)
  #def delete(id), do: get(id) |> delete()

  #def activate(%@schema{} = item),   do: item |> change(%{active: true})  |> Repo.update() |> notify_subscribers(@updated)
  #def activate(id), do: get(id) |> activate()
  #def deactivate(%@schema{} = item), do: item |> change(%{active: false}) |> Repo.update() |> notify_subscribers(@updated)
  #def deactivate(id), do: get(id) |> deactivate()
end
