defmodule DevTeamTimetracking.Timesheets do
  import Ecto.Query
  import BnwPortal.Helpers.Utility

  alias DevTeamTimetracking.Repo

  alias DevTeamTimetracking.Projects.{
    Project,
    FixedProject,
  }

  @topic "dev_team_tracking:Timesheets"
  @schema DevTeamTimetracking.Timesheets.Timesheet
  @updated [:timesheet, :updated]
  @created [:timesheet, :created]
  @deleted [:timesheet, :deleted]

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

  def timesheets_query(timeframe, date) do
    @schema
    |> join(:left, [t],    p  in Project,      on: p.id  == t.project_id)
    |> join(:left, [t, _], fp in FixedProject, on: fp.id == t.fixed_project_id)
    |> timesheets_query_filter(timeframe, date)
    |> group_by([t, p, fp], [t.user_id, t.project_id, t.fixed_project_id])
    |> order_by([_, p, fp], [asc: fp.name, asc: p.name])
    |> select([t, p, fp], %{
      name:    fragment("ifnull(?, ?)", p.name, fp.name),
      hours:   fragment("cast(sum(?) + (sum(?) div 60) as signed)", t.hours, t.minutes),
      minutes: fragment("cast(mod(sum(?), 60) as signed)", t.minutes),
    })
  end

  defp timesheets_query_filter(query, "day", date) do
    query
    |> where([t], t.entry_date == ^date)
  end
  defp timesheets_query_filter(query, "week", date) do
    query
    |> where([t], t.entry_date >= ^Date.beginning_of_week(date))
    |> where([t], t.entry_date <= ^Date.end_of_week(date))
  end
  defp timesheets_query_filter(query, "month", date) do
    query
    |> where([t], t.entry_date >= ^Date.beginning_of_month(date))
    |> where([t], t.entry_date <= ^Date.end_of_month(date))
  end
  defp timesheets_query_filter(query, "year", date) do
    query
    |> where([t], t.entry_date >= ^Date.from_iso8601!("#{date.year}-01-01"))
    |> where([t], t.entry_date <= ^Date.from_iso8601!("#{date.year}-12-31"))
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

  def filter_project(query, project_id) when not is_nil(project_id) do
    where(query, [l], l.project_id == ^project_id)
  end
  def filter_project(query, _project_id), do: query

  def filter_fixed_project(query, fixed_project_id) when not is_nil(fixed_project_id) do
    where(query, [l], l.fixed_project_id == ^fixed_project_id)
  end
  def filter_fixed_project(query, _fixed_project_id), do: query

  def list(opts \\ %{}) do
    @schema
    |> order_by(desc: :entry_date)
    |> order_by(desc: :start)
    |> order_by(desc: :id)
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_project(Map.get(opts, :project_id))
    |> filter_fixed_project(Map.get(opts, :fixed_project_id))
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
