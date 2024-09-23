defmodule AdminLogs.TurnkeyUpdates do
  import Ecto.Query
  import BnwPortal.Helpers.Utility

  alias AdminLogs.Repo

  @topic "admin_logs:turnkey_update"
  @schema AdminLogs.TurnkeyUpdates.TurnkeyUpdate
  @updated [:turnkey_update, :updated]
  @created [:turnkey_update, :created]
  @deleted [:turnkey_update, :deleted]

  def subscribe(),     do: Phoenix.PubSub.subscribe(BnwPortal.PubSub,   @topic)
  def subscribe(id),   do: Phoenix.PubSub.subscribe(BnwPortal.PubSub,   "#{@topic}:#{id}")
  def unsubscribe(),   do: Phoenix.PubSub.unsubscribe(BnwPortal.PubSub, @topic)
  def unsubscribe(id), do: Phoenix.PubSub.unsubscribe(BnwPortal.PubSub, "#{@topic}:#{id}")
  defp notify_subscribers({:ok, result}, event) do
    Phoenix.PubSub.broadcast(BnwPortal.PubSub, @topic, {event, result})
    Phoenix.PubSub.broadcast(BnwPortal.PubSub, "#{@topic}:#{result.id}", {event, result})
    {:ok, result}
  end
  defp notify_subscribers({:error, reason}, _event), do: {:error, reason}


  defp search_stack(query, search_stack) when is_list(search_stack) do
    Enum.reduce(search_stack, query, fn(search, query) ->
      cond do
        search.field == :inserted_at -> query |> where([r], r.inserted_at >= ^search.val)
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


  def list_tables(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> order_by(asc: :table)
    |> distinct(true)
    |> select([tk], %{table: tk.table})
    |> Repo.all()
    |> bnw_preload(Map.get(opts, :preload, []))
  end

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> order_by(asc: :table)
    |> order_by(desc: :id)
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
end
