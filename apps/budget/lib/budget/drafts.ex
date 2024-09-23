defmodule Budget.Drafts do
  import Ecto.Query

  import BnwPortal.Helpers.Utility

  alias Budget.{
    Drafts.VariablePlanningLine,
    Drafts.FixedPlanningLine,
    Drafts.ExtraPlanningLine,
    Drafts.MonthlyInput,
    Drafts.DraftEdit,
    Repo
  }

  @topic "budget:draft"
  @schema Budget.Drafts.Draft
  @updated [:draft, :updated]
  @created [:draft, :created]
  @deleted [:draft, :deleted]

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

  defp filter_selected(query, %{budget: budget, draft_type: draft_type}) do
    query
    |> where([d], d.company_budget_id == ^budget)
    |> where([d], d.draft_type_id     == ^draft_type)
  end
  defp filter_selected(query, nil), do: query

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_selected(Map.get(opts, :selected))
    |> Repo.all()
    |> bnw_preload(Map.get(opts, :preload, []))
  end
  def preload(val, opts \\ %{}), do: bnw_preload(val, Map.get(opts, :preload, []))

  def create_or_update(item, attrs \\ %{})
  def create_or_update(%@schema{} = item, attrs) do
    new_item = is_nil(item.id)
    item
    |> change(attrs)
    |> Repo.insert_or_update()
    |> notify_subscribers(if new_item, do: @created, else: @updated)
  end

  def create_or_update(%DraftEdit{} = item, attrs) do
    new_item = is_nil(item.id)
    item
    |> change(attrs)
    |> Repo.insert_or_update()
    |> notify_subscribers(if new_item, do: @created, else: @updated)
  end

  def get(id), do: Repo.get(@schema, id)
  def get_draft(id), do: Repo.get(DraftEdit, id)
  def new(), do: %@schema{}
  def new_draft(), do: %DraftEdit{}
  def new_changeset(attrs \\ %{}), do: new_draft() |> change(attrs)
  def change(item, attrs \\ %{})
  def change(%@schema{}   = item, attrs), do: @schema.changeset(item, attrs)
  def change(%DraftEdit{} = item, attrs), do: DraftEdit.changeset(item, attrs)
  def delete(%@schema{} = item), do: item |> Repo.delete() |> notify_subscribers(@deleted)
  def delete(id), do: get(id) |> delete()

  def toggle_lock(%@schema{} = item) do
    item |> create_or_update(%{locked: !item.locked})
  end
  def toggle_lock(id) when is_binary(id),  do: id |> String.to_integer() |> toggle_lock()
  def toggle_lock(id) when is_integer(id), do: id |> get() |> toggle_lock()

  def activate(%@schema{} = item),   do: item |> change(%{active: true})  |> Repo.update() |> notify_subscribers(@updated)
  def activate(id), do: get(id) |> activate()
  def deactivate(%@schema{} = item), do: item |> change(%{active: false}) |> Repo.update() |> notify_subscribers(@updated)
  def deactivate(id), do: get(id) |> deactivate()

  def query_variable_planning_lines(), do: from(vpl in VariablePlanningLine, order_by: [asc: vpl.id])
  def query_fixed_planning_lines(),    do: from(fpl in FixedPlanningLine,    order_by: [asc: fpl.id])
  def query_extra_planning_lines(),    do: from(epl in ExtraPlanningLine,    order_by: [asc: epl.id])
  def query_monthly_inputs(),          do: from(mi  in MonthlyInput,         order_by: [asc: mi.id])
end
