defmodule HfgPortal.Helpers.DefaultUser do
  @moduledoc """
  Provides a standardized set of CRUD operations and PubSub functionality.
  This macro can be used by any module that needs basic CRUD operations with real-time updates.
  
  Required options:
    - :schema       - The Ecto schema module to use
    - :user_schema  - The Ecto schema user module to use
    - :topic        - The PubSub topic for broadcasting changes
    - :updated      - The event type for update broadcasts
    - :created      - The event type for create broadcasts
    - :deleted      - The event type for delete broadcasts
    
  Optional options:
    - :archive - The archive schema module (defaults to nil)

  ## Example Usage

      use HfgPortal.Helpers.DefaultCrud,
        schema:      MyApp.MySchema,
        user_schema: MyApp.Users.User,
        topic:       "my_app:my_schema",
        updated:     [:my_app, :my_schema, :updated],
        created:     [:my_app, :my_schema, :created],
        deleted:     [:my_app, :my_schema, :deleted]
  """

  defmacro __using__(opts) do
    quote do
      import Ecto.Query

      alias HfgPortal.Repo

      # Module attributes from the options
      @schema       unquote(opts[:schema])      # Ecto schema module
      @user_schema  unquote(opts[:user_schema]) # Ecto schema user module
      @roles        unquote(opts[:roles])       # Roles module
      @topic        unquote(opts[:topic])       # PubSub topic
      @updated      unquote(opts[:updated])     # Update event type
      @created      unquote(opts[:created])     # Create event type
      @deleted      unquote(opts[:deleted])     # Delete event type
      @archive      unquote(opts[:archive])     # Archive schema module (optional)

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

      #Filters query by active status.
      #
      ### Parameters
      #  - query: The Ecto query to filter
      #  - active: Boolean active status to filter by
      defp filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
      defp filter_active(query, _active), do: query

      #Applies search filters to a query.
      #
      ### Parameters
      #  - query: The Ecto query to filter
      #  - search_stack: List of search criteria with `field` and `val` keys
      defp search_stack(query, search_stack) when is_list(search_stack) do
        Enum.reduce(search_stack, query, fn(search, query) ->
          cond do
            search.field in [:inserted_at, :updated_at] -> query |> where([r], field(r, ^search.field) >= ^search.val)
            search.field in @user_schema.__schema__(:fields) -> query |> where([r], like(field(r, ^search.field), ^"%#{search.val}%") or ^search.val == "")
            search.field == :role -> query |> where([_, ur], (^search.val == "None" and is_nil(ur.role)) or ur.role == ^search.val)
            search.field in @schema.__schema__(:fields) -> query |> where([_, ur], like(field(ur, ^search.field), ^"%#{search.val}%") or ^search.val == "")
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
            sort.field in @user_schema.__schema__(:fields) -> 
              query |> order_by([{^sort.order, ^sort.field}])
            sort.field == :role -> query |> order_by([_, ur], [{^sort.order, ur.role}])
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
        @user_schema
        |> join(:left, [u], ur in @schema, on: ur.user_id == u.id)      # Join with user_roles table
        |> search_stack(Map.get(opts, :search_stack))                   # Apply search filters
        |> sort_stack(Map.get(opts, :sort_stack))                       # Apply sorting
        |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page)) # Apply pagination
        |> filter_active(Map.get(opts, :active))                        # Filter by active status
        |> Repo.all()                                                   # Execute the query
        |> hfg_preload(Map.get(opts, :preload, []))                     # Load associations
        # Transform each user to include their role struct
        |> Enum.map(&(%{&1 | role: @roles.get(if &1.user_role, do: Map.get(&1.user_role, :role), else: "None")}))
      end

      @doc """
      Preloads associations for a record or list of records.
      
      ## Parameters
        - val: The record or list of records to preload associations for
        - opts: Map of options including `:preload` list
      """
      def preload(val, opts \\ %{}), do: hfg_preload(val, Map.get(opts, :preload, []))

      @doc """
      Applies pagination to a query.
      
      ## Parameters
        - query: The Ecto query to paginate
        - page: The page number (zero-based)
        - per_page: Number of items per page
      
      ## Returns
        - The paginated query with limit and offset applied
        - The original query if page or per_page is nil
      
      ## Example
          iex> hfg_paginate(query, 0, 10)  # First page with 10 items
          iex> hfg_paginate(query, 1, 20)  # Second page with 20 items
      """
      def hfg_paginate(query, page, per_page) when not is_nil(page) and not is_nil(per_page) do
        query
        |> limit(^(per_page))
        |> offset(^(page * per_page))
      end
      def hfg_paginate(query, _page, _per_page), do: query

      @doc """
      Preloads associations for a record or list of records.
      
      ## Parameters
        - val: The record or list of records to preload associations for
        - opts: Map of options including `:preload` list
      """
      def hfg_preload(query, items) when is_list(items), do: query |> HfgPortal.Repo.preload(items)
      def hfg_preload(query, _), do: query
      
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
      Retrieves a user's role by their user ID.
      Returns a single UserRole record or nil if not found.
      """
      def get(id, :user), do: @schema |> where([u], u.user_id == ^id) |> limit(1) |> Repo.one()

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
      def delete(id) when is_integer(id), do: get(id) |> delete()
      def delete(id) when is_binary(id), do: id |> String.to_integer() |> delete()

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
        search_stack:       2,
        sort_stack:         2,
        list:               1,
        create_or_update:   2,
        archive:            2,
        get:                1,
        get:                2,
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
