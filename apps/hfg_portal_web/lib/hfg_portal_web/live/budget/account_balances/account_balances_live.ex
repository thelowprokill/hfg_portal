defmodule HfgPortalWeb.Budget.AccountBalances.AccountBalancesLive do
  use HfgPortalWeb, :live_view

  alias Budget.{Accounts, AccountBalances, Authorize}

  defp fetch_accounts(socket), do: socket |> assign(:accounts, Accounts.list())

  defp fetch_can_edit(socket) do
    %{current_user: user} = socket.assigns
    assign(socket, :can_edit, Authorize.can_edit?(user))
  end

  defp fetch_balances(socket) do
    %{selected_year: year, selected_month: month} = socket.assigns
    socket |> assign(:balances, AccountBalances.map_for_month(year, month))
  end

  defp shift_month(year, month, :prev) when month == 1, do: {year - 1, 12}
  defp shift_month(year, month, :prev), do: {year, month - 1}
  defp shift_month(year, month, :next) when month == 12, do: {year + 1, 1}
  defp shift_month(year, month, :next), do: {year, month + 1}

  defp apply_month(socket, year, month) do
    %{session: session} = socket.assigns

    socket
    |> assign(:selected_year, year)
    |> assign(:selected_month, month)
    |> assign(
      :session,
      session |> Map.put("year", to_string(year)) |> Map.put("month", to_string(month))
    )
  end

  defp handle_params(socket, %{"app" => app} = session) do
    %{session: stored} = socket.assigns

    socket
    |> assign(:session, Map.put(stored, "app", app))
    |> handle_params(Map.delete(session, "app"))
  end

  defp handle_params(socket, %{"page" => page} = session) do
    %{session: stored} = socket.assigns

    socket
    |> assign(:session, Map.put(stored, "page", page))
    |> handle_params(Map.delete(session, "page"))
  end

  defp handle_params(socket, %{"admin" => admin} = session) do
    %{session: stored} = socket.assigns

    socket
    |> assign(:session, Map.put(stored, "admin", admin))
    |> handle_params(Map.delete(session, "admin"))
  end

  defp handle_params(socket, %{"year" => year, "month" => month} = session) do
    %{session: stored} = socket.assigns

    socket
    |> assign(:session, stored |> Map.put("year", year) |> Map.put("month", month))
    |> assign(:selected_year, String.to_integer(year))
    |> assign(:selected_month, String.to_integer(month))
    |> handle_params(session |> Map.delete("year") |> Map.delete("month"))
  end

  defp handle_params(socket, _session), do: socket

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
      AccountBalances.subscribe()
    end

    today = Date.utc_today()

    socket
    |> bnw_verify_user_token(session, "Budget", "Account Balances")
    |> assign(:session, %{})
    |> assign(:accounts, [])
    |> assign(:balances, %{})
    |> assign(:selected_year, today.year)
    |> assign(:selected_month, today.month)
    |> assign(:can_edit, false)
    |> fetch_accounts()
    |> fetch_can_edit()
    |> handle_params(session)
    |> fetch_balances()
    |> res(:ok)
  end

  @impl true
  def handle_info({[:account, _], _account}, socket) do
    socket |> fetch_accounts() |> fetch_balances() |> res()
  end

  @impl true
  def handle_info({[:account_balance, _], _balance}, socket) do
    socket |> fetch_balances() |> res()
  end

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("reset_month", _, socket) do
    today = Date.utc_today()

    socket
    |> apply_month(today.year, today.month)
    |> fetch_balances()
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("prev_month", _, socket) do
    {year, month} =
      shift_month(socket.assigns.selected_year, socket.assigns.selected_month, :prev)

    socket |> apply_month(year, month) |> fetch_balances() |> push_changes(:patch) |> res()
  end

  @impl true
  def handle_event("next_month", _, socket) do
    {year, month} =
      shift_month(socket.assigns.selected_year, socket.assigns.selected_month, :next)

    socket |> apply_month(year, month) |> fetch_balances() |> push_changes(:patch) |> res()
  end

  @impl true
  def handle_event(
        "save",
        %{"balances" => balances_params},
        %{assigns: %{can_edit: true}} = socket
      ) do
    %{selected_year: year, selected_month: month} = socket.assigns

    Enum.each(balances_params, fn {account_id, balance} ->
      AccountBalances.upsert(String.to_integer(account_id), year, month, %{balance: balance})
    end)

    socket |> fetch_balances() |> res()
  end

  @impl true
  def handle_event("save", _params, socket), do: socket |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
