defmodule CarMaintenance.UserRoles do
  @topic "car_maintenance:user_roles"
  @schema CarMaintenance.Users.UserRole
  @user_schema CarMaintenance.Users.User
  @updated [:car_maintenance, :user_role, :updated]
  @created [:car_maintenance, :user_role, :created]
  @deleted [:car_maintenance, :user_role, :deleted]

  alias CarMaintenance.{Users.Roles}

  use HfgPortal.Helpers.DefaultUser, 
    schema:      @schema,
    user_schema: @user_schema,
    roles:       Roles,
    topic:       @topic,
    updated:     @updated,
    created:     @created,
    deleted:     @deleted

  #use HfgPortal.Helpers.DefaultCrud, 
  #  schema:  @schema,
  #  topic:   @topic,
  #  updated: @updated,
  #  created: @created,
  #  deleted: @deleted
  
  #def get(id, :user), do: @schema |> where([u], u.user_id == ^id) |> limit(1) |> Repo.one()

  #def filter_dev_user(query, true), do: query |> where([u, ur], not is_nil(ur.id))
  #def filter_dev_user(query, _), do: query

  #def list(opts \\ %{}) do
  #  @user_schema
  #  |> join(:left, [u], ur in @schema, on: ur.user_id == u.id)
  #  |> search_stack(Map.get(opts, :search_stack))
  #  |> sort_stack(Map.get(opts, :sort_stack))
  #  |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
  #  |> filter_active(Map.get(opts, :active))
  #  |> filter_dev_user(Map.get(opts, :dev_user))
  #  |> Repo.all()
  #  |> bnw_preload(Map.get(opts, :preload, []))
  #  |> Enum.map(&(%{&1 | role: Roles.get(if &1.user_role, do: Map.get(&1.user_role, :role), else: "None")}))
  #end

  #import Ecto.Query
  #import HfgPortal.Helpers.Utility

  #alias CarMaintenance.{Repo, Users.User, Users.Roles}

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


  #defp search_stack(query, search_stack) when is_list(search_stack) do
  #  Enum.reduce(search_stack, query, fn(search, query) ->
  #    cond do
  #      search.field == :role -> query |> where([u, ur], like(ur.role, ^"%#{search.val}%") or ^search.val == "" or ^search.val == "None" and is_nil(ur.id))
  #      search.field in @schema.__schema__(:fields) -> query |> where([r], like(field(r, ^search.field), ^"%#{search.val}%") or ^search.val == "")
  #      true -> query
  #    end
  #  end)
  #end
  #defp search_stack(query, nil), do: query

  #defp sort_stack(query, sort_stack) when is_list(sort_stack) do
  #  Enum.reduce(sort_stack, query, fn(sort, query) ->
  #    cond do
  #      sort.field == :role  -> query |> order_by([u, ur], [{^sort.order, ur.role}])
  #      sort.field in @schema.__schema__(:fields) -> query |> order_by([{^sort.order, ^sort.field}])
  #      true -> query
  #    end
  #  end)
  #end
  #defp sort_stack(query, nil), do: query

  #def filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
  #def filter_active(query, _active), do: query

  #def filter_dev_user(query, true), do: query |> where([u, ur], not is_nil(ur.id))
  #def filter_dev_user(query, _), do: query

  #def list(opts \\ %{}) do
  #  User
  #  |> join(:left, [u], ur in @schema, on: ur.user_id == u.id)
  #  |> search_stack(Map.get(opts, :search_stack))
  #  |> sort_stack(Map.get(opts, :sort_stack))
  #  |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
  #  |> filter_active(Map.get(opts, :active))
  #  |> filter_dev_user(Map.get(opts, :dev_user))
  #  |> Repo.all()
  #  |> bnw_preload(Map.get(opts, :preload, []))
  #  |> Enum.map(&(%{&1 | role: Roles.get(if &1.user_role, do: Map.get(&1.user_role, :role), else: "None")}))
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
  #def get(id, :user), do: @schema |> where([u], u.user_id == ^id) |> limit(1) |> Repo.one()
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
