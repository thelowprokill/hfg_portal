defmodule HullFamilyGamesWeb.DevTools.InfiniteScroll.InfiniteScrollLive do
  use HullFamilyGamesWeb, :live_view

  alias HullFamilyGames.{
    Accounts,
    InfiniteScrollTest
  }

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h3 class="text-xl">Infinite Scroll</h3>

      <div class="py-6"><.bnw_button_new /></div>
      <div class="py-3"><.bnw_button_primary phx_click="reset_filters">Reset Filters</.bnw_button_primary></div>
      
      <.form :let={s}
        for={@search_map}
        as={:search}
        phx-change="search"
        phx-submit="search">
        <.bnw_table id="infinite_scroll_table">
          <:header>
            <th class="p-2"><.bnw_table_header_filter f={s} search_stack={@search_stack} sort_stack={@sort_stack} field={:name}>Name</.bnw_table_header_filter></th>
            <th class="p-2"></th>
            <th class="p-2"></th>
          </:header>
          <%= for item <- @items do %>
            <tr>
              <td><%= item.name %></td>
              <td><.bnw_button_edit   phx-value-id={item.id} /></td>
              <td><.bnw_button_delete phx-value-id={item.id} /></td>
            </tr>
          <% end %>
        </.bnw_table>
    </.form>

    </div>
    <%= if @modal do %>
      <.bnw_modal id="infinite_scroll_modal">
        <.bnw_modal_header>Create Item</.bnw_modal_header>
        <.form :let={f}
          for={@modal.changeset}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

              <.bnw_input f={f} field={:name} display_name="Name" />

          </.bnw_modal_body>
        <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit /></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    <% end %>
    """
  end

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    socket
    |> assign(:modal, %Modal{
      modal:     :new,
      id:        :new,
      changeset: InfiniteScrollTest.new_changeset()
    })
  end

  defp set_modal(socket, :edit, id) do
    changeset = 
      id
      |> InfiniteScrollTest.get()
      |> InfiniteScrollTest.change()

    socket
    |> assign(:modal, %Modal{
      modal:     :edit,
      id:        :id,
      changeset: changeset
    })
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal, nil)

  defp fetch_items(socket) do
    %{
      page:         page,
      per_page:     per_page,
      items:        items,
      search_stack: search_stack,
      sort_stack:   sort_stack
    } = socket.assigns

    socket
    |> assign(:items, items ++ InfiniteScrollTest.list(%{
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack
    }))
  end
  defp reload_items(socket), do: socket |> assign(:items, []) |> fetch_items()

  defp save(socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    cond do
      changeset.valid? ->
        changeset.data |> InfiniteScrollTest.create_or_update(changeset.changes)
        |> case do
          {:ok, _} -> socket |> set_modal()
          {:error, changeset} -> socket |> assign(:modal, %{modal | changeset: changeset})
        end
      true -> socket
    end
  end

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
      InfiniteScrollTest.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Infinite Scroll")
    |> assign(:page,             0)
    |> assign(:per_page,         20)
    |> assign(:items,            [])
    |> assign(:search_map,       %{}) # search map is for the search form
    |> assign(:search_stack,     [])  # search stack is the data for all the search fields
    |> assign(:sort_stack,       [])  # sort stack is the data for all the sort fields
    |> assign(:session,          %{}) # session is kept so that the session can be updated
    |> handle_params(session)         # here session is the second argument to mount
    |> fetch_items()
    |> set_modal()
    |> res(:ok)
  end

  # note that handle_params is not the normal callback function, so this can be changed as needed
  defp handle_params(socket, %{"search" => _search} = session) do 
    socket
    |> search_handle_params(session)
    |> handle_params(session |> Map.delete("search"))
  end
  defp handle_params(socket, %{"sort" => _sort} = session) do 
    socket
    |> sort_handle_params(session)
    |> handle_params(session |> Map.delete("sort"))
  end

  # these are required to keep on the app, page and admin
  defp handle_params(socket, %{"app" => app} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "app", app))
    |> handle_params(session |> Map.delete("app"))
  end
  defp handle_params(socket, %{"page" => page} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "page", page))
    |> handle_params(session |> Map.delete("page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "admin", admin))
    |> handle_params(session |> Map.delete("admin"))
  end
  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:item, :created], item}, socket) do
    %{items: items} = socket.assigns
    socket 
    |> assign(:items, [item | items])
    |> assign(:update_direction, "prepend")
    |> res()
  end

  @impl true
  def handle_info({[:item, :updated], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.map(items, fn i -> if i.id == item.id, do: item, else: i end)) |> res()
  end

  @impl true
  def handle_info({[:item, :deleted], item}, socket) do
    %{items: items} = socket.assigns
    socket 
    |> assign(:items, items |> Enum.reject(&(&1.id == item.id)))
    |> assign(:update_direction, "replace")
    |> res()
  end

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("add_new", _, socket), do: set_modal(socket, :new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: set_modal(socket, :edit, id |> String.to_integer()) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id |> String.to_integer() |> InfiniteScrollTest.delete()
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_event("validate", %{"item" => params}, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    changeset = 
      changeset.data
      |> InfiniteScrollTest.change(params)
      |> Map.put(:action, :insert)

    socket
    |> assign(:modal, %{modal | changeset: changeset})
    |> res()
  end

  @impl true
  def handle_event("save", %{"item" => params}, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    changeset =
      changeset.data
      |> InfiniteScrollTest.change(params)
      |> Map.put(:action, :insert)

    socket
    |> assign(:modal, %{modal | changeset: changeset})
    |> save()
    |> res()
  end

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page,             page + 1)
    |> assign(:update_direction, "append")
    |> fetch_items()
    |> res()
  end

  @impl true
  def handle_event("sort", params, socket), do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket), do: socket |> search_reset_filter(field) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", _, socket), do: socket |> search_reset_filter() |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket), do: socket |> search(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"field" => _} = params, socket), do: search(socket, params) |> res()
  @impl true
  def handle_event("hide_filter", _, socket), do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
