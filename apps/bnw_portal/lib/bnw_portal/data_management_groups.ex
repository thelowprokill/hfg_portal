defmodule BnwPortal.DataManagementGroups do
  import Ecto.Query

  import BnwPortal.Helpers.Utility

  alias BnwPortal.Repo
  alias BnwPortal.DataManagementItems.DataManagementItem

  @topic "bnw_portal:data_management_groups"
  @schema BnwPortal.DataManagementGroups.DataManagementGroup
  @updated [:data_management_group, :updated]
  @created [:data_management_group, :created]
  @deleted [:data_management_group, :deleted]

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

  def item_query(), do: from(i in DataManagementItem, order_by: i.order)

  def move_up(id) do
    group = get(id)
    prev_group =
      @schema
      |> where([r], r.order < ^group.order)
      |> order_by([r], desc: r.order)
      |> limit(1)
      |> Repo.one()

    Ecto.Multi.new()
    |> Ecto.Multi.insert_or_update(:group,      group      |> change(%{order: prev_group.order}))
    |> Ecto.Multi.insert_or_update(:prev_group, prev_group |> change(%{order: group.order}))
    |> Repo.transaction(timeout: 300_000)
    |> case do
      {:ok, data} ->
        notify_subscribers({:ok, data.group},      @updated)
        notify_subscribers({:ok, data.prev_group}, @updated)
      {:error, _, _} ->
        :error
      _ ->
        :error
    end
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

  def filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
  def filter_active(query, _active), do: query

  defp filter_budget(query, budget_id) when not is_nil(budget_id), do: where(query, [ba], ba.budget_id == ^budget_id)
  defp filter_budget(query, _budget_id), do: query

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> filter_budget(Map.get(opts, :budget_id))
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
