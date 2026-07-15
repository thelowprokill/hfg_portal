defmodule HfgPortalWeb.Budget.Balances.BalancesLive do
  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Budget.Balances.Modals.ChangeAccountBalance

  alias Budget.{Accounts, AccountBalances}

  defp set_modal(socket, :balance, id) when not is_nil(id) do
    %{modal_stack: modal_stack, current_user: user, balances: balances} = socket.assigns
    account = Accounts.get(id)
    balance = Map.get(balances, account.id, Decimal.new(0))

    socket
    |> assign(:modal_stack, [
      %Modal{
        modal: :balance,
        id: :balance,
        module: ChangeAccountBalance,
        changeset: AccountBalances.new_changeset(%{account_id: account.id, date: Date.utc_today(), balance: balance}),
        live: false,
        user: user,
        opts: %{account: account}
      }
      | modal_stack
    ])
  end

  defp set_modal(socket, _, _),
    do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: AccountBalances.subscribe()

    socket
    |> bnw_verify_user_token(session, "Budget", "Balances")
    |> assign(:modal_stack, [])
    |> assign(:accounts, Accounts.list(%{}))
    |> assign(:balances, AccountBalances.map_for_date(Date.utc_today()))
    |> assign(:balance_dates, AccountBalances.dates_for_date(Date.utc_today()))
    |> res(:ok)
  end

  @impl true
  def handle_info({[:account_balance, :created], balance}, socket) do
    socket
    |> assign(:balances, Map.put(socket.assigns.balances, balance.account_id, balance.balance))
    |> assign(:balance_dates, Map.put(socket.assigns.balance_dates, balance.account_id, balance.date))
    |> res()
  end

  @impl true
  def handle_info({[:account_balance, :updated], balance}, socket) do
    socket
    |> assign(:balances, Map.put(socket.assigns.balances, balance.account_id, balance.balance))
    |> assign(:balance_dates, Map.put(socket.assigns.balance_dates, balance.account_id, balance.date))
    |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal(nil, nil) |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("set_balance", %{"id" => id}, socket),
    do: socket |> set_modal(:balance, String.to_integer(id)) |> res()

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal(nil, nil) |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
