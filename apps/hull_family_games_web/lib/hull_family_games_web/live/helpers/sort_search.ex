defmodule HullFamilyGamesWeb.Helpers.SortSearch do
  use Phoenix.LiveView

  alias HullFamilyGames.Helpers.{
    Search,
    Sort,
  }

  @moduledoc """
  This is the helper module for the search system.
  This system stores the search and sort in the params and allows for multilevel search and sort.
  The search is stored in the params as:
  search=field_1|val_1,field_2|val_2...
  for example:
  search=account|Travel,period|1,budget|2024

  The sort is stored in the params as:
  sort=order_1|field_1,order_2|field_2...
  for example:
  sort=asc|budget,desc|period,asc|account&

  To Use this search/sort system you need to add the following to your context:

  # Adjust this cond for weird cases such as join tables
  defp search_stack(query, search_stack) when is_list(search_stack) do
    Enum.reduce(search_stack, query, fn(search, query) ->
      cond do
        true -> query |> where([yd], like(field(yd, ^search.field), ^"%{search.val}%") or ^search.val == "")
      end
    end)
  end
  defp search_stack(query, nil), do: query

  # Adjust this cond for weird cases such as join tables
  defp sort_stack(query, sort_stack) when is_list(sort_stack) do
    Enum.reduce(sort_stack, query, fn(sort, query) ->
      cond do
        true -> query |> order_by([{^sort.order, ^sort.field}])
      end
    end)
  end
  defp sort_stack(query, nil), do: query


  And add the following to your live view:

  # Adjust this function to clear the items and reload them
  defp reload_items(socket), do: socket |> assign(:users, []) |> fetch_users()

  # set these values in mount
    |> assign(:search_map,   %{}) # search map is for the search form
    |> assign(:search_stack, [])  # search stack is the data for all the search fields
    |> assign(:sort_stack,   [])  # sort stack is the data for all the sort fields
    |> assign(:session,      %{}) # session is kept so that the session can be updated
    |> handle_params(session)     # here session is the second argument to mount

  # add these handle_params functions
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

  # add these handle_event functions
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

  In the heex template you will need to add something like this:

  <div class="py-3"><.bnw_button_primary phx_click="reset_filters">Reset Filters</.bnw_button_primary></div>
  <.form :let={s}
    for={@search_map}
    as={:search}
    phx-change="search"
    phx-submit="search">
    <.bnw_table>
      <:header>
        <th class="p-2"><.bnw_table_header_filter f={s} search_stack={@search_stack} sort_stack={@sort_stack} field={:username}>  User Name </.bnw_table_header_filter></th>
        <th class="p-2"><.bnw_table_header_filter f={s} search_stack={@search_stack} sort_stack={@sort_stack} field={:first_name}>First Name</.bnw_table_header_filter></th>
        <th class="p-2"><.bnw_table_header_filter f={s} search_stack={@search_stack} sort_stack={@sort_stack} field={:last_name}> Last Name </.bnw_table_header_filter></th>
        <th class="p-2"><.bnw_table_header_filter f={s} search_stack={@search_stack} sort_stack={@sort_stack} field={:email}>     Email     </.bnw_table_header_filter></th>
        <th class="p-2"><.bnw_table_header_filter f={s} search_stack={@search_stack} sort_stack={@sort_stack} field={:role} type="select" list={@roles}>Role</.bnw_table_header_filter></th>
        <th class="p-2"></th>
      </:header>
      <!-- table body here -->
    </.bnw_table>
  </.form>


  """

  def search_handle_params(socket, %{"search" => search}) do
    %{session: stored_session} = socket.assigns

    search_stack = 
      search
      |> String.split(",")
      |> Enum.map(&String.split(&1, "|"))
      |> Enum.map(fn [field, val] -> %Search{field: String.to_existing_atom(field), val: val} end)

    search_map = 
      search_stack
      |> Enum.find(&(&1.show))
      |> case do
        nil -> %{}
        search -> %{"val" => search.val, "field" => Atom.to_string(search.field)}
      end

    socket
    |> assign(:session, Map.put(stored_session, "search", search))
    |> assign(:search_stack, search_stack)
    |> assign(:search_map, search_map)
  end
    
  def sort_handle_params(socket, %{"sort" => sort}) do
    %{session: stored_session} = socket.assigns

    sort_stack = 
      sort
      |> String.split(",")
      |> Enum.map(&String.split(&1, "|"))
      |> Enum.map(fn [order, field] -> %Sort{field: String.to_existing_atom(field), order: String.to_existing_atom(order)} end)

    socket
    |> assign(:session, Map.put(stored_session, "sort", sort))
    |> assign(:sort_stack, sort_stack)
  end

  def search(socket, %{"search" => search}) do
    %{search_stack: search_stack} = socket.assigns

    field = search["field"] |> String.to_existing_atom()
    value = search["val"]

    socket
    |> assign(:search_stack, Enum.map(search_stack, &(if &1.field == field, do: %Search{&1 | val: value}, else: &1)))
    |> assign(:search_map, %{})
    |> assign(:page, 0)
    |> put_search()
  end

  def search(socket, %{"field" => field_string}) do
    %{search_stack: search_stack} = socket.assigns

    field = field_string |> String.to_existing_atom()
    cond do
      Enum.any?(search_stack, &(&1.field == field)) ->
        search = Enum.find(search_stack, &(&1.field == field))
                      |> fn x -> %Search{x | show: !x.show} end.()

        search_stack = Enum.reject(search_stack, &(&1.field == field))
                       |> Enum.map(&(%{&1 | show: false}))
        socket
        |> assign(:search_stack, [search | search_stack])
        |> assign(:search_map, %{"val" => search.val, "field" => field})
      true ->
        socket
        |> assign(:search_stack, [%Search{val: "", field: field, show: true} | search_stack |> Enum.map(&(%{&1 | show: false}))])
        |> assign(:search_map, %{"val" => "", "field" => field_string})
    end
  end

  def sort(socket, %{"field" => field_string}) do
    %{sort_stack: sort_stack} = socket.assigns

    field = field_string |> String.to_existing_atom()


    sort_stack = cond do
      Enum.any?(sort_stack, &(&1.field == field)) && Enum.find(sort_stack, &(&1.field == field)).order == :asc ->
        Enum.map(sort_stack, &(if &1.field == field, do: %{&1 | order: :desc}, else: &1))
      Enum.any?(sort_stack, &(&1.field == field)) && Enum.find(sort_stack, &(&1.field == field)).order == :desc ->
        Enum.reject(sort_stack, &(&1.field == field))
      true -> sort_stack ++ [%Sort{field: field, order: :asc}]
    end

    socket
    |> assign(:sort_stack, sort_stack)
    |> assign(:page,       0)
    |> put_sort()
  end

  def sort(socket, %{"field" => field, "order" => order}) do
    %{sort_stack: sort_stack} = socket.assigns

    sort_stack = 
      sort_stack
      |> Enum.reject(&(&1.field == String.to_existing_atom(field)))
      |> fn x -> x ++ [%Sort{field: String.to_existing_atom(field), order: String.to_existing_atom(order)}] end.()

    socket
    |> assign(:sort_stack, sort_stack)
    |> put_sort()
  end
  
  def search_hide_filter(socket) do
    %{search_stack: search_stack} = socket.assigns

    search_stack = search_stack |> Enum.map(&(%{&1 | show: false}))

    socket
    |> assign(:search_stack, search_stack)
    |> put_search()
  end
  def search_reset_filter(socket, field) do
    %{search_stack: search_stack} = socket.assigns

    socket
    |> assign(:search_stack, search_stack |> Enum.reject(&(&1.field == field |> String.to_existing_atom())))
    |> assign(:page, 0)
    |> assign(:search_map, %{})
    |> put_search()
  end
  def search_reset_filter(socket) do
    %{ session: session } = socket.assigns

    socket
    |> assign(:search_stack, [])
    |> assign(:sort_stack,   [])
    |> assign(:search_map,   %{})
    |> assign(:page,         0)
    |> assign(:session,      session |> Map.delete("search") |> Map.delete("sort"))
    |> HullFamilyGamesWeb.Helpers.Utility.push_changes(:patch)
  end

  defp put_search(socket) when socket.assigns.search_stack == [] do
    socket |> assign(:session, Map.delete(socket.assigns.session, "search")) |> HullFamilyGamesWeb.Helpers.Utility.push_changes(:patch)
  end
  defp put_search(socket) do
    %{
      search_stack: search_stack,
      session:      session
    } = socket.assigns

    search = 
      search_stack
      |> Enum.reduce("", fn x, acc -> "#{acc},#{x.field}|#{x.val}" end)
      |> String.trim_leading(",")

    socket
    |> assign(:session, Map.put(session, "search", search))
    |> HullFamilyGamesWeb.Helpers.Utility.push_changes(:patch)
  end

  defp put_sort(socket) when socket.assigns.sort_stack == [] do
    socket |> assign(:session, Map.delete(socket.assigns.session, "sort")) |> HullFamilyGamesWeb.Helpers.Utility.push_changes()
  end
  defp put_sort(socket) do
    %{
      sort_stack: sort_stack,
      session:      session
    } = socket.assigns

    sort = 
      sort_stack
      |> Enum.reverse()
      |> Enum.reduce("", fn x, acc -> "#{x.order}|#{x.field},#{acc}" end)
      |> String.trim_trailing(",")

    socket
    |> assign(:session, Map.put(session, "sort", sort))
    |> HullFamilyGamesWeb.Helpers.Utility.push_changes(:patch)
  end

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"
end
