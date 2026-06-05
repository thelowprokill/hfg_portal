defmodule HfgPortalWeb.Budget.ScheduledExpenses.ScheduledExpensesLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Budget.ScheduledExpenses.Modals.ChangeScheduledExpense

  alias Budget.{
    Buckets,
    ScheduledExpenses,
    Repo,
  }

  @preload [:bucket]

  defp fetch_scheduled_expenses(socket) do
    %{
      page:         page,
      per_page:     per_page,
      scheduled_expenses: scheduled_expenses,
      search_stack: search_stack,
      sort_stack:   sort_stack,
    } = socket.assigns

    fetched = ScheduledExpenses.list(%{
      page:         page,
      per_page:     per_page,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      preload:      @preload,
    })

    socket |> assign(:scheduled_expenses, scheduled_expenses ++ fetched)
  end

  defp reload_items(socket), do: socket |> assign(:scheduled_expenses, []) |> assign(:page, 0) |> fetch_scheduled_expenses()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{modal_stack: modal_stack, current_user: user, buckets: buckets} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeScheduledExpense,
      changeset: ScheduledExpenses.new_changeset(),
      live:      false,
      user:      user,
      opts:      %{buckets: buckets}
    } | modal_stack])
  end

  defp set_modal(socket, :edit, id) when not is_nil(id) do
    %{modal_stack: modal_stack, current_user: user, buckets: buckets} = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :edit,
      id:        :edit,
      module:    ChangeScheduledExpense,
      changeset: ScheduledExpenses.get(id) |> ScheduledExpenses.change(),
      live:      false,
      user:      user,
      opts:      %{buckets: buckets}
    } | modal_stack])
  end

  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: ScheduledExpenses.subscribe()

    socket
    |> bnw_verify_user_token(session, "Budget", "Scheduled Expenses")
    |> assign(:session,             %{})
    |> assign(:page,                0)
    |> assign(:per_page,            50)
    |> assign(:scheduled_expenses,  [])
    |> assign(:modal_stack,         [])
    |> assign(:search_map,          %{})
    |> assign(:search_stack,        [])
    |> assign(:sort_stack,          [])
    |> then(fn s ->
      %{current_user: %{id: uid}} = s.assigns
      assign(s, :buckets, Buckets.list_for_user(uid))
    end)
    |> handle_params(session)
    |> fetch_scheduled_expenses()
    |> res(:ok)
  end

  defp handle_params(socket, %{"app" => app} = session) do
    %{session: stored} = socket.assigns
    socket |> assign(:session, Map.put(stored, "app", app)) |> handle_params(Map.delete(session, "app"))
  end
  defp handle_params(socket, %{"page" => page} = session) do
    %{session: stored} = socket.assigns
    socket |> assign(:session, Map.put(stored, "page", page)) |> handle_params(Map.delete(session, "page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do
    %{session: stored} = socket.assigns
    socket |> assign(:session, Map.put(stored, "admin", admin)) |> handle_params(Map.delete(session, "admin"))
  end
  defp handle_params(socket, %{"search" => _} = session) do
    socket |> search_handle_params(session) |> handle_params(Map.delete(session, "search"))
  end
  defp handle_params(socket, %{"sort" => _} = session) do
    socket |> sort_handle_params(session) |> handle_params(Map.delete(session, "sort"))
  end
  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:scheduled_expense, :created], expense}, socket) do
    socket |> assign(:scheduled_expenses, [expense |> Repo.preload(@preload) | socket.assigns.scheduled_expenses]) |> res()
  end
  @impl true
  def handle_info({[:scheduled_expense, :updated], expense}, socket) do
    socket |> assign(:scheduled_expenses, Enum.map(socket.assigns.scheduled_expenses, &(if &1.id == expense.id, do: expense |> Repo.preload(@preload), else: &1))) |> res()
  end
  @impl true
  def handle_info({[:scheduled_expense, :deleted], expense}, socket) do
    socket |> assign(:scheduled_expenses, Enum.reject(socket.assigns.scheduled_expenses, &(&1.id == expense.id))) |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("run_scheduled", _, socket) do
    %{scheduled_expenses: expenses, sinking_contributions: sinking} =
      ScheduledExpenses.run_scheduled()

    expense_count = Enum.count(expenses, &(&1.status == :created))
    sinking_count = Enum.count(sinking,  &(&1.status == :created))

    msg = "Ran scheduled: #{expense_count} expense(s) created, #{sinking_count} sinking fund contribution(s) added."

    socket
    |> put_flash(:info, msg)
    |> reload_items()
    |> res()
  end

  @impl true
  def handle_event("add_new", _, socket),                         do: socket |> set_modal(:new) |> res()
  @impl true
  def handle_event("edit", %{"id" => id}, socket),                do: socket |> set_modal(:edit, String.to_integer(id)) |> res()
  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    ScheduledExpenses.delete(String.to_integer(id))
    socket |> res()
  end
  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    expense = ScheduledExpenses.get(String.to_integer(id))
    if expense.active,
      do:   ScheduledExpenses.deactivate(expense),
      else: ScheduledExpenses.activate(expense)
    socket |> res()
  end
  @impl true
  def handle_event("cancel", _, socket),                          do: socket |> set_modal() |> res()
  @impl true
  def handle_event("load_more", _, socket) do
    socket |> assign(:page, socket.assigns.page + 1) |> fetch_scheduled_expenses() |> res()
  end
  @impl true
  def handle_event("sort", params, socket),                       do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket),  do: socket |> search(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"field" => _} = params, socket),   do: socket |> search(params) |> res()
  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket),  do: socket |> search_reset_filter(field) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", _, socket),                   do: socket |> search_reset_filter() |> reload_items() |> res()
  @impl true
  def handle_event("hide_filter", _, socket),                     do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
