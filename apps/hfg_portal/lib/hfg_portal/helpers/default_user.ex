defmodule HfgPortal.Helpers.DefaultUser do
  defmacro __using__(opts) do
    quote do
      import Ecto.Query
      import HfgPortal.Helpers.Utility

      alias HfgPortal.Repo

      @schema      unquote(opts[:schema])
      @archive     unquote(opts[:archive])
      @user_schema unquote(opts[:user_schema])
      @roles       unquote(opts[:roles])
      @topic       unquote(opts[:topic])
      @updated     unquote(opts[:updated])
      @created     unquote(opts[:created])
      @deleted     unquote(opts[:deleted])

      def subscribe(),     do: Phoenix.PubSub.subscribe(HfgPortal.PubSub,   @topic)
      def subscribe(id),   do: Phoenix.PubSub.subscribe(HfgPortal.PubSub,   "#{@topic}:#{id}")
      def unsubscribe(),   do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, @topic)
      def unsubscribe(id), do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, "#{@topic}:#{id}")
      defp notify_subscribers({:ok, result}, event) do
        Phoenix.PubSub.broadcast(HfgPortal.PubSub, @topic, {event, result})
        Phoenix.PubSub.broadcast(HfgPortal.PubSub, "#{@topic}:#{result.id}", {event, result})
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

      defp filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
      defp filter_active(query, _active), do: query

      def filter_dev_user(query, true), do: query |> where([u, ur], not is_nil(ur.id))
      def filter_dev_user(query, _), do: query

      def list(opts \\ %{}) do
        @user_schema
        |> join(:left, [u], ur in @schema, on: ur.user_id == u.id)
        |> search_stack(Map.get(opts, :search_stack))
        |> sort_stack(Map.get(opts, :sort_stack))
        |> paginate(opts)
        |> filter_active(Map.get(opts, :active))
        |> filter_dev_user(Map.get(opts, :dev_user))
        |> Repo.all()
        |> hfg_preload(Map.get(opts, :preload, []))
        |> Enum.map(&(%{&1 | role: @roles.get(if &1.user_role, do: Map.get(&1.user_role, :role), else: "None")}))
      end

      def preload_associations(val, opts \\ %{})
      def preload_associations(val, %{preload: preload}), do: hfg_preload(val, preload)
      def preload_associations(val, _), do: val

      def paginate(query, opts \\ %{})
      def paginate(query, %{page: page, per_page: per_page}), do:
        query
        |> limit(^(per_page))
        |> offset(^(page * per_page))
      def paginate(query, _), do: query

      def create_or_update(%@schema{} = item, attrs \\ %{}) do
        new_item = is_nil(item.id)
        item
        |> change(attrs)
        |> Repo.insert_or_update()
        |> archive(attrs)
        |> notify_subscribers(if new_item, do: @created, else: @updated)
      end

      if @archive do
        defp archive({:ok, %@schema{} = item}, attrs) when not is_nil(@schema) do
          new_attrs =
            item
            |> Map.from_struct()
            |> Map.drop([:__meta__, :id, :inserted_at, :updated_at])
            |> Map.merge(attrs, fn _, _, v -> v end)
            |> Map.put(:item_id, item.id)

          %@archive{}
          |> @archive.changeset(new_attrs)
          |> Repo.insert()
          {:ok, item}
        end
      end
      defp archive(ret, _), do: ret

      def get(id), do: Repo.get(@schema, id)
      def get(id, :user), do: @schema |> where([u], u.user_id == ^id) |> limit(1) |> Repo.one()
      def new(), do: %@schema{}
      def new_changeset(attrs \\ %{}), do: new() |> change(attrs)
      def change(%@schema{} = item, attrs \\ %{}), do: @schema.changeset(item, attrs)
      def delete(%@schema{} = item), do: item |> Repo.delete() |> notify_subscribers(@deleted)
      def delete(id), do: get(id) |> delete()

      def activate(item, key \\ :active)
      def activate(%@schema{} = item, key),   do: item |> change(Map.put(%{}, key, true))  |> Repo.update() |> notify_subscribers(@updated)
      def activate(id, key), do: get(id) |> activate(key)
      def deactivate(item, key \\ :active)
      def deactivate(%@schema{} = item, key), do: item |> change(Map.put(%{}, key, false)) |> Repo.update() |> notify_subscribers(@updated)
      def deactivate(id, key), do: get(id) |> deactivate(key)

      defoverridable [
        notify_subscribers:   2,
        search_stack:         2,
        sort_stack:           2,
        filter_active:        2,
        list:                 1,
        preload_associations: 2,
        paginate:             2,
        create_or_update:     2,
        get:                  1,
        new:                  0,
        new_changeset:        1,
        change:               2,
        delete:               1,
        activate:             2,
        deactivate:           2,
      ]
    end
  end
end
