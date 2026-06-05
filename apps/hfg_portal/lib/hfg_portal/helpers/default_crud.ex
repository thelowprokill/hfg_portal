defmodule HfgPortal.Helpers.DefaultCrud do
  @moduledoc """
  Provides a standardized set of CRUD operations and PubSub functionality.
  This macro can be used by any module that needs basic CRUD operations with real-time updates.
  
  Required options:
    - :schema  - The Ecto schema module to use
    - :topic   - The PubSub topic for broadcasting changes
    - :updated - The event type for update broadcasts
    - :created - The event type for create broadcasts
    - :deleted - The event type for delete broadcasts
    
  Optional options:
    - :archive - The archive schema module (defaults to nil)

  ## Example Usage

      use HfgPortal.Helpers.DefaultCrud,
        schema: MyApp.MySchema,
        topic: "my_app:my_schema",
        updated: [:my_app, :my_schema, :updated],
        created: [:my_app, :my_schema, :created],
        deleted: [:my_app, :my_schema, :deleted]
  """

  defmacro __using__(opts) do
    quote do
      import Ecto.Query, except: [preload: 2]
      import HfgPortal.Helpers.Utility

      alias HfgPortal.Repo

      # Module attributes from the options
      @schema  unquote(opts[:schema])   # Ecto schema module
      @topic   unquote(opts[:topic])    # PubSub topic
      @updated unquote(opts[:updated])  # Update event type
      @created unquote(opts[:created])  # Create event type
      @deleted unquote(opts[:deleted])  # Delete event type
      @archive unquote(opts[:archive])  # Archive schema module (optional)

      @doc """
      Subscribes to all changes for this resource type.
      
      ## Example
          iex> subscribe()
          :ok
      """
      def subscribe(), do: Phoenix.PubSub.subscribe(HfgPortal.PubSub, @topic)

      @doc """
      Subscribes to changes for a specific resource ID.
      
      ## Parameters
        - id: The ID of the resource to subscribe to
      
      ## Example
          iex> subscribe(123)
          :ok
      """
      def subscribe(id), do: Phoenix.PubSub.subscribe(HfgPortal.PubSub, "#{@topic}:#{id}")

      @doc """
      Unsubscribes from all changes for this resource type.
      
      ## Example
          iex> unsubscribe()
          :ok
      """
      def unsubscribe(), do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, @topic)

      @doc """
      Unsubscribes from changes for a specific resource ID.
      
      ## Parameters
        - id: The ID of the resource to unsubscribe from
      
      ## Example
          iex> unsubscribe(123)
          :ok
      """
      def unsubscribe(id), do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, "#{@topic}:#{id}")

      #Notifies subscribers of changes to a resource.
      #
      ### Parameters
      #  - result: The result tuple from a database operation
      #  - event: The type of event that occurred
      #
      ### Returns
      #  - `{:ok, result}` on success
      #  - `{:error, reason}` on failure
      defp notify_subscribers({:ok, result}, event) do
        Phoenix.PubSub.broadcast(HfgPortal.PubSub, @topic, {event, result})
        Phoenix.PubSub.broadcast(HfgPortal.PubSub, "#{@topic}:#{result.id}", {event, result})
        {:ok, result}
      end
      defp notify_subscribers({:error, reason}, _event), do: {:error, reason}

      @doc """
      Moves a record up in display order by swapping its order value with the previous record.
      
      ## Parameters
        - id: The ID of the record to move up

      ## Requires
        - `:order` field in the schema
      
      ## Process
        1. Retrieves the target record
        2. Finds the previous record (with lower order value in same group)
        3. Swaps the order values between the two records
        4. Notifies subscribers of the updates
      
      ## Returns
        - `:ok` on success
        - `:error` if the transaction fails
      """
      def move_up(id) do
        item = get(id)
        prev_item = 
          @schema
          |> where([r], r.order < ^item.order)
          |> order_by([r], desc: r.order)
          |> limit(1)
          |> Repo.one()

        Ecto.Multi.new()
        |> Ecto.Multi.insert_or_update(:item,      item      |> change(%{order: prev_item.order}))
        |> Ecto.Multi.insert_or_update(:prev_item, prev_item |> change(%{order: item.order}))
        |> Repo.transaction(timeout: 300_000)
        |> case do
          {:ok, data} ->
            notify_subscribers({:ok, data.item},      @updated)
            notify_subscribers({:ok, data.prev_item}, @updated)
          {:error, _, _} ->
            :error
          _ ->
            :error
        end
      end

      #Filters query by active status.
      #
      ### Parameters
      #  - query: The Ecto query to filter
      #  - active: Boolean active status to filter by
      defp filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
      defp filter_active(query, _active), do: query

      #Filters query by archive status.
      #
      ### Parameters
      #  - query: The Ecto query to filter
      #  - active: Boolean archive status to filter by
      defp filter_archive(query, archive) when not is_nil(archive), do: query |> where(archive: ^archive)
      defp filter_archive(query, _archive), do: query

      #Applies search filters to a query.
      #
      ### Parameters
      #  - query: The Ecto query to filter
      #  - search_stack: List of search criteria with `field` and `val` keys
      defp search_stack(query, search_stack) when is_list(search_stack) do
        Enum.reduce(search_stack, query, fn(search, query) ->
          cond do
            search.field in [:inserted_at, :updated_at] -> query |> where([r], field(r, ^search.field) >= ^search.val)
            search.field in @schema.__schema__(:fields) -> query |> where([r], like(field(r, ^search.field), ^"%#{search.val}%") or ^search.val == "")
            true -> query
          end
        end)
      end
      defp search_stack(query, nil), do: query

      #Applies sorting to a query.
      #
      ### Parameters
      #  - query: The Ecto query to sort
      #  - sort_stack: List of sort criteria with `field` and `order` keys
      defp sort_stack(query, sort_stack) when is_list(sort_stack) do
        Enum.reduce(sort_stack, query, fn(sort, query) ->
          cond do
            sort.field in @schema.__schema__(:fields) -> 
              query |> order_by([{^sort.order, ^sort.field}])
            true -> query
          end
        end)
      end
      defp sort_stack(query, nil), do: query

      @doc """
      Lists records with support for filtering, sorting, and pagination.
      
      ## Parameters
        - opts: Map of options including:
          - `:search_stack` - List of search criteria
          - `:sort_stack` - List of sort criteria
          - `:page` - Page number for pagination
          - `:per_page` - Items per page
          - `:active` - Filter by active status
          - `:preload` - List of associations to preload
      
      ## Example
          iex> list(%{page: 1, per_page: 10, active: true})
          [%Schema{}, ...]
      """
      def list(opts \\ %{}) do
        @schema
        |> search_stack(Map.get(opts, :search_stack))
        |> sort_stack(Map.get(opts, :sort_stack))
        |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
        |> filter_active(Map.get(opts, :active))
        |> filter_archive(Map.get(opts, :archive))
        |> HfgPortal.Repo.all()
        |> hfg_preload(Map.get(opts, :preload, []))
      end

      @doc """
      Preloads associations for a record or list of records.
      
      ## Parameters
        - val: The record or list of records to preload associations for
        - opts: Map of options including `:preload` list
      """
      def preload(val, opts \\ %{}), do: hfg_preload(val, Map.get(opts, :preload, []))
      
      @doc """
      Creates or updates a record.
      
      ## Parameters
        - item: The schema struct to create or update
        - attrs: Map of attributes to set
      
      ## Returns
        - `{:ok, schema}` on success
        - `{:error, changeset}` on failure
      """
      def create_or_update(%@schema{} = item, attrs \\ %{}) do
        #new_item = is_nil(item.id)
        new_item = item |> Map.get(:id) |> is_nil()
        item
        |> change(attrs)
        |> HfgPortal.Repo.insert_or_update()
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

      @doc """
      Gets a single record by ID.
      
      ## Parameters
        - id: The ID of the record to fetch
      """
      def get(id), do: Repo.get(@schema, id)

      @doc """
      Creates a new empty schema struct.
      """
      def new(), do: %@schema{}

      @doc """
      Creates a new changeset with the given attributes.
      
      ## Parameters
        - attrs: Map of attributes for the new changeset
      """
      def new_changeset(attrs \\ %{}), do: new() |> change(attrs)

      @doc """
      Creates a changeset for the given record and attributes.
      
      ## Parameters
        - item: The schema struct to create a changeset for
        - attrs: Map of attributes to change
      """
      def change(%@schema{} = item, attrs \\ %{}), do: @schema.changeset(item, attrs)

      @doc """
      Deletes a record.
      
      ## Parameters
        - item: The schema struct to delete
        
      ## Returns
        - `{:ok, schema}` on success
        - `{:error, changeset}` on failure
      """
      def delete(%@schema{} = item), do: item |> HfgPortal.Repo.delete() |> notify_subscribers(@deleted)
      def delete(id), do: get(id) |> delete()

      @doc """
      Activates a record by setting the specified field to true.
      
      ## Parameters
        - item: The schema struct or ID to activate
        - key: The field to set to true (defaults to :active)
      
      ## Returns
        - `{:ok, schema}` on success
        - `{:error, changeset}` on failure
      
      ## Example
          iex> activate(123)                # Sets active: true
          {:ok, %Schema{active: true}}
          
          iex> activate(123, :published)    # Sets published: true
          {:ok, %Schema{published: true}}
      """
      def activate(item, key \\ :active)
      def activate(%@schema{} = item, key), do: item |> change(Map.put(%{}, key, true)) |> HfgPortal.Repo.update() |> notify_subscribers(@updated)
      def activate(id, key), do: get(id) |> activate(key)

      @doc """
      Deactivates a record by setting the specified field to false.
      
      ## Parameters
        - item: The schema struct or ID to deactivate
        - key: The field to set to false (defaults to :active)
      
      ## Returns
        - `{:ok, schema}` on success
        - `{:error, changeset}` on failure
      
      ## Example
          iex> deactivate(123)              # Sets active: false
          {:ok, %Schema{active: false}}
          
          iex> deactivate(123, :published)  # Sets published: false
          {:ok, %Schema{published: false}}
      """
      def deactivate(item, key \\ :active)
      def deactivate(%@schema{} = item, key), do: item |> change(Map.put(%{}, key, false)) |> HfgPortal.Repo.update() |> notify_subscribers(@updated)
      def deactivate(id, key), do: get(id) |> deactivate(key)

      # Allow modules to override any of these functions
      defoverridable [
        notify_subscribers: 2,
        move_up:            1,
        search_stack:       2,
        sort_stack:         2,
        list:               1,
        create_or_update:   2,
        archive:            2,
        get:                1,
        new:                0,
        new_changeset:      1,
        change:             2,
        delete:             1,
        activate:           1,
        deactivate:         1,
      ]
    end
  end
end
