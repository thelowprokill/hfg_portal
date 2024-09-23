defmodule DevTeamTimetracking.FavoriteProjects do
  import Ecto.Query
  import BnwPortal.Helpers.Utility

  alias DevTeamTimetracking.Repo

  @topic "dev_team_tracking:FavoriteProjects"
  @schema DevTeamTimetracking.Projects.FavoriteProject
  @updated [:favorite_project, :updated]
  @created [:favorite_project, :created]
  @deleted [:favorite_project, :deleted]

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

  def filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
  def filter_active(query, _active), do: query

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> order_by(asc: :name)
    |> filter_active(Map.get(opts, :active))
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

  # set favorite project or fixed project
  def set(id, user_id, value, project \\ :project)
  def set(id, user_id, true, :project) when is_integer(id) and is_integer(user_id), do: new() |> create_or_update(%{project_id: id, user_id: user_id})
  def set(id, user_id, true, :fixed)   when is_integer(id) and is_integer(user_id), do: new() |> create_or_update(%{fixed_project_id: id, user_id: user_id})
  def set(id, user_id, false, :project) when is_integer(id) and is_integer(user_id) do 
    @schema
    |> where([i], i.project_id == ^id and i.user_id == ^user_id) 
    |> Repo.all() 
    |> Enum.map(&delete/1)
  end
  def set(id, user_id, false, :fixed)   when is_integer(id) and is_integer(user_id), do: @schema |> where([i], i.figed_project_id == ^id and i.user_id == ^user_id) |> Repo.all() |> Enum.map(&delete/1)
  def set(id, user_id, value, project) when is_binary(id),      do: set(String.to_integer(id), user_id, value, project)
  def set(id, user_id, value, project) when is_binary(user_id), do: set(id, String.to_integer(user_id), value, project)

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
