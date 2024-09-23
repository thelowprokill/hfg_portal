defmodule BnwPortalWeb.ItBudget.Budgets.BudgetsLive do
  use BnwPortalWeb, :live_view

  alias BnwPortalWeb.ItBudget.Budgets.Modals.{
    ChangeBudgets,
    ChangeBudgetAccounts,
  }
  alias ItBudget.{
    Budgets
  }

  defp fetch_budgets(socket) do
    %{
      page:         page,
      per_page:     per_page,
      budgets:      budgets, 
      search_stack: search_stack,
      sort_stack:   sort_stack
    } = socket.assigns

    socket |> assign(:budgets, budgets ++ Budgets.list(
      %{
        page:         page,
        per_page:     per_page,
        search_stack: search_stack,
        sort_stack:   sort_stack
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end
  defp reload_items(socket), do: socket |> assign(:budgets, []) |> fetch_budgets()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _id) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %{
      modal:     :new,
      id:        :new,
      module:    ChangeBudgets,
      changeset: Budgets.new_changeset(%{year: Date.utc_today().year}),
      user:      user
    }))
  end
  defp set_modal(socket, :edit, id) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %{
      modal:     :edit,
      id:        id,
      module:    ChangeBudgets,
      changeset: id |> Budgets.get() |> Budgets.change(),
      user:      user
    }))
  end

  defp set_modal(socket, :edit_accounts, id) do
    %{
      budgets:      budgets,
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %{
      modal:       :edit,
      id:          id,
      module:      ChangeBudgetAccounts,
      live:        true,
      user:        user,
      budget_year: Enum.find(budgets, &(&1.id == id)).year,
      budget_id:   id,
    }))
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Budgets.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "IT Budget", "Budgets")
    |> assign(:page,         0)
    |> assign(:per_page,     30)
    |> assign(:budgets,      [])
    |> assign(:modal_stack,  [])
    |> assign(:search_map,   %{}) # search map is for the search form
    |> assign(:search_stack, [])  # search stack is the data for all the search fields
    |> assign(:sort_stack,   [])  # sort stack is the data for all the sort fields
    |> assign(:session,      %{}) # session is kept so that the session can be updated
    |> handle_params(session)     # here session is the second argument to mount
    |> fetch_budgets()
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
  def handle_info({[:budget, :created], budget}, socket) do
    socket
    |> assign(:budgets, [budget | socket.assigns.budgets])
    |> res()
  end

  @impl true
  def handle_info({[:budget, :updated], budget}, socket) do
    socket
    |> assign(:budgets, Enum.map(socket.assigns.budgets, fn b -> if b.id == budget.id, do: budget, else: b end))
    |> res()
  end

  @impl true
  def handle_info({[:budget, :deleted], budget}, socket) do
    socket
    |> assign(:budgets, Enum.reject(socket.assigns.budgets, fn b -> b.id == budget.id end))
    |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("add_new", _, socket), do: set_modal(socket, :new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: set_modal(socket, :edit, id |> String.to_integer) |> res()

  @impl true
  def handle_event("edit_accounts", %{"id" => id}, socket), do: set_modal(socket, :edit_accounts, id |> String.to_integer) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do  
    id |> String.to_integer |> Budgets.delete()
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_budgets()
    |> res()
  end

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

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
