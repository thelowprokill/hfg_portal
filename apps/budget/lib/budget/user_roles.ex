defmodule Budget.UserRoles do
  import Ecto.Query

  import BnwPortal.Helpers.Utility

  alias Budget.{
    Users.Role,
    Repo
  }

  @topic "budget:user_role"
  @schema Budget.Users.UserRole
  @updated [:budget, :user_role, :updated]
  @created [:budget, :user_role, :created]
  @deleted [:budget, :user_role, :deleted]

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

  def fetch_user_permissions(user_id) do
    users_roles = list(%{
      user_id: user_id, 
      preload: [role: from(role in Role, where: role.active, preload: [:company_permissions, :home_permissions])]
    })
    |> Enum.reject(&is_nil(&1.role))

    company_permissions = Enum.reduce(users_roles, [], fn user_role, acc -> acc ++ user_role.role.company_permissions end)
    home_permissions    = Enum.reduce(users_roles, [], fn user_role, acc -> acc ++ user_role.role.home_permissions end)
    %{company_permissions: company_permissions, home_permissions: home_permissions}
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

  def filter_user(query, user_id) when not is_nil(user_id), do: query |> where(user_id: ^user_id)
  def filter_user(query, _user_id), do: query

  def filter_company(query, company_id) when not is_nil(company_id) do
    where(query, [l], l.company_id == ^company_id)
  end
  def filter_company(query, _company_id), do: query

  def filter_role(query, role_id) when not is_nil(role_id) do
    where(query, [l], l.role_id == ^role_id)
  end
  def filter_role(query, _role_id), do: query

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> filter_user(Map.get(opts, :user_id))
    #|> filter_company(Map.get(opts, :company_id))
    |> filter_role(Map.get(opts, :role_id))
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
