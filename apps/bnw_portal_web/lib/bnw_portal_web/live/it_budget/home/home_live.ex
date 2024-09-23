defmodule BnwPortalWeb.ItBudget.Home.HomeLive do
  use BnwPortalWeb, :live_view

  alias BnwPortalWeb.ItBudget.Home.Modals.ChangeYtdDetails

  alias ItBudget.{
    Budgets,
    YtdDetails,
    Users.Roles,
    UserRoles,
    Reports,
    Repo,
  }

  defp fetch_details(socket) do
    %{
      page:         page,
      per_page:     per_page,
      details:      details,
      search_stack: search_stack,
      sort_stack:   sort_stack
    } = socket.assigns

    socket |> assign(:details, details ++ YtdDetails.list(
      %{
        page:         page,
        per_page:     per_page,
        search_stack: search_stack,
        sort_stack:   sort_stack,
        preload:      [:budget, :account],
      }
    ))
  end

  defp reload_items(socket), do: socket |> assign(:details, []) |> fetch_details()
  defp fetch_budgets(socket), do: socket |> assign(:budgets, Budgets.list(%{active: true}))
  defp fetch_reports(socket), do: socket |> assign(:reports, Reports.list(%{active: true}))

  defp fetch_user_role(socket) do
    %{current_user: user} = socket.assigns
    socket 
    |> assign(:user_role, UserRoles.get(user.id, :user) 
    |> case do
      _ when user.dev_admin and user.admin_mode -> "Admin"
      nil -> "None"
      user_role -> user_role |> Map.get(:role, "None") 
    end
    |> Roles.get())
  end

  defp default_tranfer_form(socket) do
    %{budgets: budgets} = socket.assigns

    cur_date  = Date.utc_today()
    cur_year  = cur_date.year
    last_month = cur_date.month - 1
    period =
      last_month - 10
      |> case do
        val when val < 0 -> val + 12
        val -> val
      end

    cond do
      last_month >= 10 ->
        socket |> assign(:transfer_form, %{
          "budget" => "#{Enum.find(budgets, %{id: nil}, &(&1.year == cur_year + 1)).id}",
          "period" => "#{period}"
        })
      true ->
        socket |> assign(:transfer_form, %{
          "budget" => "#{Enum.find(budgets, %{id: nil}, &(&1.year == cur_year)).id}",
          "period" => "#{period}"
        })
    end

  end

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal: :new,
      id:    :new,
      module: ChangeYtdDetails,
      changeset: YtdDetails.new_changeset(),
      user: user
    } | modal_stack])
  end

  defp set_modal(socket, :edit, id) do
    %{
      modal_stack:  modal_stack,
      current_user: user
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal: :edit,
      id:    :edit,
      module: ChangeYtdDetails,
      changeset: id |> YtdDetails.get() |> YtdDetails.change(),
      user: user
    } | modal_stack])
  end

  defp set_modal(socket, :reports, id) when not is_nil(id) do
    %{ 
      modal_stack: modal_stack,
      reports:     reports
    } = socket.assigns
    socket
    |> assign(:modal_stack, [%Modal{
      modal:  :report,
      id:     :report,
      opts:   %{report: Enum.find(reports, &(&1.id == id)) |> Reports.decorate()},
    } | modal_stack])
  end

  defp set_modal(socket, :reports, _) do
    %{ 
      modal_stack: modal_stack,
      reports:     reports
    } = socket.assigns

    socket
    |> assign(:modal_stack, 
      cond do
        length(reports) == 1 ->
          [%Modal{
            modal:  :report,
            id:     :report,
            opts:   %{report: Enum.at(reports, 0) |> Reports.decorate()},
          } | modal_stack]
        length(reports) > 1 ->
          [ %Modal{
            modal:  :pick_reports,
            id:     :pick_reports,
            module: nil
          } | modal_stack]
        true -> 
          modal_stack
      end)
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      YtdDetails.subscribe()
      UserRoles.subscribe()
      Reports.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "IT Budget", "Home")
    |> fetch_user_role()
    |> assign(:session,       %{})
    |> assign(:page,          0)
    |> assign(:per_page,      50)
    |> assign(:details,       [])
    |> assign(:reports,       [])
    |> assign(:modal_stack,   [])
    |> assign(:search_map,    %{})
    |> assign(:search_stack,  [])
    |> assign(:sort_stack,    [])
    |> handle_params(session)
    |> fetch_details()
    |> fetch_budgets()
    |> fetch_reports()
    |> default_tranfer_form()
    |> res(:ok)
  end

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
  def handle_info({[:ytd_detail, :created], ytd_detail}, socket) do
    socket
    |> assign(:details, [ytd_detail |> Repo.preload([:budget, :account]) | socket.assigns.details])
    |> res()
  end
  @impl true
  def handle_info({[:ytd_detail, :updated], ytd_detail}, socket) do
    socket
    |> assign(:details, Enum.map(socket.assigns.details, &(if &1.id == ytd_detail.id, do: ytd_detail |> Repo.preload([:budget, :account]), else: &1)))
    |> res()
  end
  @impl true
  def handle_info({[:ytd_detail, :deleted], ytd_detail}, socket) do
    socket
    |> assign(:details, Enum.reject(socket.assigns.details, &(&1.id == ytd_detail.id)))
    |> res()
  end
  @impl true
  def handle_info({[:ytd_detail, :transfered], _}, socket) do
    socket
    |> assign(page: 0)
    |> assign(:details, [])
    |> fetch_details()
    |> assign(page: 1)
    |> fetch_details()
    |> res()
  end

  @impl true
  def handle_info({[:report, :created], report}, socket) do
    socket
    |> assign(:reports, [report | socket.assigns.reports])
    |> res()
  end
  @impl true
  def handle_info({[:report, :updated], report}, socket) do
    %{reports: reports} = socket.assigns
    socket
    |> assign(:reports, cond do
      Enum.any?(reports, &(&1.id == report.id)) -> Enum.map(reports, &(if &1.id == report.id, do: report, else: &1))
      true -> [report | reports]
    end |> Enum.filter(&(&1.active)))
    |> res()
  end
  @impl true
  def handle_info({[:report, :deleted], report}, socket) do
    socket
    |> assign(:reports, Enum.reject(socket.assigns.reports, &(&1.id == report.id)))
    |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_info({[:it_budget, :user_role, _], user_role}, socket) do
    socket
    |> case do
      socket when socket.assigns.current_user.id == user_role.user_id -> fetch_user_role(socket)
      socket -> socket
    end
    |> res()
  end

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("add_new", _, socket), do: socket |> set_modal(:new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: socket |> set_modal(:edit, id |> String.to_integer) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do 
    id |> String.to_integer |> YtdDetails.delete()
    socket |> res()
  end

  @impl true
  def handle_event("reports", %{"id" => id}, socket), do: socket |> set_modal(:reports, id |> String.to_integer) |> res()

  @impl true
  def handle_event("reports", _, socket), do: socket |> set_modal(:reports) |> res()

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("transfer_ytd_validate", %{"transfer_ytd" => params}, socket), do: socket |> assign(:transfer_form, params) |> res()

  @impl true
  def handle_event("transfer_ytd", %{"transfer_ytd" => %{"budget" => budget, "period" => period}}, socket) do
    YtdDetails.transfer_ytd(String.to_integer(budget), String.to_integer(period))
    socket |> res()
  end

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_details()
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
