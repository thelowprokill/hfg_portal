defmodule BnwPortalWeb.ItBudget.Home.Modals.ChangeYtdDetails do
  use BnwPortalWeb, :live_component

  @module ItBudget.YtdDetails
  @key "ytd_detail"

  alias ItBudget.{
    Budgets,
    Accounts,
  }

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="ytd_detail_modal">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>Budget</.bnw_modal_new_or_edit></.bnw_modal_header>
        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <.bnw_input_hidden f={f} field={:user_id} value={@modal.user.id} />
            <.bnw_input        f={f} field={:budget_id}        display_name="Budget"           type="select" list={@budgets |> Enum.map(&([key: &1.year, value: &1.id]))} />
            <.bnw_input        f={f} field={:account_id}       display_name="Account"          type="select" list={@accounts |> Enum.map(&([key: &1.name, value: &1.id]))} />
            <.bnw_input        f={f} field={:amount}           display_name="Amount"           type="number" />
            <.bnw_input        f={f} field={:trx_date}         display_name="Date"             type="date" />
            <.bnw_input        f={f} field={:period}           display_name="Period"           type="month" starting_month={10} offset={0}/>
            <.bnw_input        f={f} field={:description}      display_name="Description"      type="textarea" />
            <.bnw_input        f={f} field={:detail_reference} display_name="Detail Reference" type="textarea" />

          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit/></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  defp fetch_budgets(socket) do
    socket
    |> assign(:budgets, Budgets.list(%{active: true}))
  end

  defp fetch_accounts(socket) do
    socket
    |> assign(:accounts, Accounts.list(%{active: true}))
  end

  defp save(socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    cond do
      changeset.valid? ->
        changeset.data |> @module.create_or_update(changeset.changes)
        |> case do
          {:ok, _} -> socket |> cancel()
          {:error, changeset} ->
            socket |> assign(:modal, %{modal | changeset: changeset})
        end
      true -> socket
    end
  end

  defp cancel(socket) do
    #%{parent: parent} = socket.assigns
    send(self(), :cancel)
    socket
  end

  @impl true
  def mount(socket) do
    socket
    |> fetch_budgets()
    |> fetch_accounts()
    |> res(:ok)
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    params = params |> Map.get(@key, %{})

    changeset =
      changeset.data
      |> @module.change(params)
      |> Map.put(:action, :insert)

    socket
    |> assign(:modal, %{modal | changeset: changeset})
    |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    params = params |> Map.get(@key, %{})

    changeset =
      changeset.data
      |> @module.change(params)
      |> Map.put(:action, :insert)

    socket
    |> assign(:modal, %{modal | changeset: changeset})
    |> save()
    |> res()
  end

  #@impl true
  #def handle_event("cancel", _, socket), do: cancel(socket) |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end

