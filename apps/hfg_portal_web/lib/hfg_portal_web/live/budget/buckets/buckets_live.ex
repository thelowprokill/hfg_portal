defmodule HfgPortalWeb.Budget.Buckets.BucketsLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Budget.Buckets.Modals.ChangeBucket

  alias Budget.Buckets

  defp fetch_buckets(socket) do
    %{
      page:         page,
      per_page:     per_page,
      buckets:      buckets,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      current_user: %{id: user_id}
    } = socket.assigns

    fetched = Buckets.list(%{
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack,
    })
    |> Enum.filter(&(&1.user_id == user_id))

    socket |> assign(:buckets, buckets ++ fetched)
  end

  defp reload_items(socket), do: socket |> assign(:buckets, []) |> assign(:page, 0) |> fetch_buckets()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{modal_stack: modal_stack, current_user: user} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeBucket,
      changeset: Buckets.new_changeset(%{user_id: user.id}),
      live:      false,
      user:      user,
      opts:      %{}
    } | modal_stack])
  end

  defp set_modal(socket, :edit, id) when not is_nil(id) do
    %{modal_stack: modal_stack, current_user: user} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :edit,
      id:        :edit,
      module:    ChangeBucket,
      changeset: Buckets.get(id) |> Buckets.change(),
      live:      false,
      user:      user,
      opts:      %{}
    } | modal_stack])
  end

  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: Buckets.subscribe()

    socket
    |> bnw_verify_user_token(session, "Budget", "Buckets")
    |> assign(:session,      %{})
    |> assign(:page,         0)
    |> assign(:per_page,     50)
    |> assign(:buckets,      [])
    |> assign(:modal_stack,  [])
    |> assign(:search_map,   %{})
    |> assign(:search_stack, [])
    |> assign(:sort_stack,   [])
    |> handle_params(session)
    |> fetch_buckets()
    |> res(:ok)
  end

  defp handle_params(socket, %{"search" => _} = session) do
    socket |> search_handle_params(session) |> handle_params(Map.delete(session, "search"))
  end
  defp handle_params(socket, %{"sort" => _} = session) do
    socket |> sort_handle_params(session) |> handle_params(Map.delete(session, "sort"))
  end
  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:bucket, :created], bucket}, socket) do
    socket |> assign(:buckets, [bucket | socket.assigns.buckets]) |> res()
  end
  @impl true
  def handle_info({[:bucket, :updated], bucket}, socket) do
    socket |> assign(:buckets, Enum.map(socket.assigns.buckets, &(if &1.id == bucket.id, do: bucket, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:bucket, :deleted], bucket}, socket) do
    socket |> assign(:buckets, Enum.reject(socket.assigns.buckets, &(&1.id == bucket.id))) |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("add_new", _, socket),                      do: socket |> set_modal(:new) |> res()
  @impl true
  def handle_event("edit", %{"id" => id}, socket),             do: socket |> set_modal(:edit, String.to_integer(id)) |> res()
  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    Buckets.delete(String.to_integer(id))
    socket |> res()
  end
  @impl true
  def handle_event("cancel", _, socket),                       do: socket |> set_modal() |> res()
  @impl true
  def handle_event("load_more", _, socket) do
    socket |> assign(:page, socket.assigns.page + 1) |> fetch_buckets() |> res()
  end
  @impl true
  def handle_event("sort", params, socket),                    do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket), do: socket |> search(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"field" => _} = params, socket),  do: socket |> search(params) |> res()
  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket), do: socket |> search_reset_filter(field) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", _, socket),                do: socket |> search_reset_filter() |> reload_items() |> res()
  @impl true
  def handle_event("hide_filter", _, socket),                  do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
