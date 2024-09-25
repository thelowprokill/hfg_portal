defmodule HfgPortalWeb.LoanRepayment.Home.HomeLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.LoanRepayment.Home.Modals.{
    ChangeLoan,
    ChangeRepayment,
  }

  alias LoanRepayment.{
    Loans,
    Repayments,
    Repo,
  }

  @preload [repayment: Repayments.repayment_query()]

  defp fetch_loans(socket) do
    %{
      page:         page,
      per_page:     per_page,
      loans:         loans,
      search_stack: search_stack,
      sort_stack:   sort_stack,
      current_user: %{id: user_id}
    } = socket.assigns

    socket |> assign(:loans, loans ++ Loans.list(
      %{
        user_id:      user_id,
        page:         page,
        per_page:     per_page,
        search_stack: search_stack,
        sort_stack:   sort_stack,
        #active:       true,
        preload:      @preload
      }
    ))
  end

  defp reload_items(socket), do: socket |> assign(:loans, []) |> fetch_loans()
  #defp fetch_reports(socket), do: socket |> assign(:reports, Reports.list(%{active: true}))

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    socket |> assign(:modal_stack, [%Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeLoan,
      changeset: Loans.new_changeset(%{created_by_id: user.id}),
      live:      false,
      user:      user,
      opts:      %{}
    } | modal_stack])
  end

  defp set_modal(socket, :edit, id) when not is_nil(id) do
    %{
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    changeset = Loans.get(id) |> Loans.change()

    socket |> assign(:modal_stack, [%Modal{
      modal:     :edit,
      id:        :edit,
      module:    ChangeLoan,
      changeset: changeset,
      live:      false,
      user:      user,
      opts:      %{}
    } | modal_stack])
  end

  defp set_modal(socket, :repayment, id) when not is_nil(id) do
    %{
      loans:           loans,
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    loan = Enum.find(loans, &(&1.id == id))

    socket |> assign(:modal_stack, [%Modal{
      modal:     :repayment,
      id:        :repayment,
      module:    ChangeRepayment,
      live:      true,
      user:      user,
      opts:      %{loan: loan}
    } | modal_stack])
  end

  defp set_modal(socket, :maintenance_items, id) when not is_nil(id) do
    %{
      loans:           loans,
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    loan = 
      loans
      |> Enum.find(&(&1.id == id))

    socket |> assign(:modal_stack, [%Modal{
      modal:     :maintenance_items,
      id:        :maintenance_items,
      module:    ChangeMaintenanceItems,
      live:      true,
      user:      user,
      opts:      %{loan_id: id, loan_name: loan.name}
    } | modal_stack])
  end

  defp set_modal(socket, :service_history, id) when not is_nil(id) do
    %{
      loans:           loans,
      modal_stack:    modal_stack,
      current_user:   user
    } = socket.assigns

    loan = 
      loans
      |> Enum.find(&(&1.id == id))

    socket |> assign(:modal_stack, [%Modal{
      modal:     :service_history,
      id:        :service_history,
      module:    ChangeServiceHistory,
      live:      true,
      user:      user,
      opts:      %{loan: loan}
    } | modal_stack])
  end
  #defp set_modal(socket, :reports, id) when not is_nil(id) do
  #  %{ 
  #    modal_stack: modal_stack,
  #    reports:     reports
  #  } = socket.assigns
  #  socket
  #  |> assign(:modal_stack, [%Modal{
  #    modal:  :report,
  #    id:     :report,
  #    opts:   %{report: Enum.find(reports, &(&1.id == id)) |> Reports.decorate()},
  #  } | modal_stack])
  #end

  #defp set_modal(socket, :reports, _) do
  #  %{ 
  #    modal_stack: modal_stack,
  #    reports:     reports
  #  } = socket.assigns

  #  socket
  #  |> assign(:modal_stack, 
  #    cond do
  #      length(reports) == 1 ->
  #        [%Modal{
  #          modal:  :report,
  #          id:     :report,
  #          opts:   %{report: Enum.at(reports, 0) |> Reports.decorate()},
  #        } | modal_stack]
  #      length(reports) > 1 ->
  #        [ %Modal{
  #          modal:  :pick_reports,
  #          id:     :pick_reports,
  #          module: nil
  #        } | modal_stack]
  #      true -> 
  #        modal_stack
  #    end)
  #end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Loans.subscribe()
      Repayments.subscribe()
      #Reports.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Loan Maintenance", "Home")
    #|> fetch_user_role()
    |> assign(:session,       %{})
    |> assign(:page,          0)
    |> assign(:per_page,      50)
    |> assign(:loans,      [])
    |> assign(:reports,       [])
    |> assign(:modal_stack,   [])
    |> assign(:capacity,      %{})
    |> assign(:search_map,    %{})
    |> assign(:search_stack,  [])
    |> assign(:sort_stack,    [])
    |> handle_params(session)
    |> fetch_loans()
    #|> fetch_reports()
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
  def handle_info({[:repayment, _], repayment}, socket) do
    socket
    |> assign(:loans, Enum.map(socket.assigns.loans, &(if &1.id == repayment.loan_id, do: &1.id |> Loans.get() |> Repo.preload(@preload), else: &1)))
    |> res()
  end

  @impl true
  def handle_info({[:loan, :created], loan}, socket) do
    socket
    |> assign(:loans, [loan |> Repo.preload(@preload) | socket.assigns.loans])
    |> res()
  end
  @impl true
  def handle_info({[:loan, :updated], loan}, socket) do
    socket
    |> assign(:loans, Enum.map(socket.assigns.loans, &(if &1.id == loan.id, do: loan |> Repo.preload(@preload), else: &1)))
    |> res()
  end
  @impl true
  def handle_info({[:loan, :deleted], loan}, socket) do
    socket
    |> assign(:loans, Enum.reject(socket.assigns.loans, &(&1.id == loan.id)))
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
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("repayment", %{"id" => id}, socket), do: socket |> set_modal(:repayment, id |> String.to_integer) |> res()

  @impl true
  def handle_event("add_new", _, socket), do: socket |> set_modal(:new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: socket |> set_modal(:edit, id |> String.to_integer) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do 
    Loans.delete(id) 
    socket |> res()
  end

  @impl true
  def handle_event("reports", %{"id" => id}, socket), do: socket |> set_modal(:reports, id |> String.to_integer) |> res()

  @impl true
  def handle_event("reports", _, socket), do: socket |> set_modal(:reports) |> res()

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_loans()
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
