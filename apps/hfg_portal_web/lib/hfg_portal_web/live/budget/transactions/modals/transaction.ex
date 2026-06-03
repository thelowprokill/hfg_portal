defmodule HfgPortalWeb.Budget.Transactions.Modals.ChangeTransaction do
  use HfgPortalWeb, :live_component

  @module Budget.Transactions
  @key    "transaction"

  @types [
    [key: "Expense",              value: "expense"],
    [key: "Contribution",         value: "contribution"],
    [key: "Sinking Fund Deposit", value: "sinking_fund_deposit"],
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="transaction">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>Transaction</.bnw_modal_new_or_edit></.bnw_modal_header>
        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <.bnw_input_hidden f={f} field={:created_by_id} value={@modal.user.id} />

            <% bucket_list = Enum.map(@modal.opts.buckets, &[key: &1.name, value: &1.id]) %>
            <.bnw_input f={f} type="select" field={:bucket_id}        display_name="Bucket"           list={bucket_list} />
            <.bnw_input f={f} field={:description}                    display_name="Description" />
            <.bnw_input f={f} type="money"  field={:amount}           display_name="Amount" />
            <.bnw_input f={f} type="select" field={:type}             display_name="Type"             list={@types} />
            <.bnw_input f={f} type="date"   field={:transaction_date} display_name="Transaction Date" />

          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit /></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  defp save(socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    if changeset.valid? do
      changeset.data
      |> @module.create_or_update(changeset.changes)
      |> case do
        {:ok, _}     -> cancel(socket)
        {:error, cs} -> socket |> assign(:modal, %{modal | changeset: cs})
      end
    else
      socket
    end
  end

  defp cancel(socket) do
    send(self(), :cancel)
    socket
  end

  @impl true
  def mount(socket) do
    socket
    |> assign(:types, @types)
    |> res(:ok)
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns
    params = Map.get(params, @key, %{})
    changeset = changeset.data |> @module.change(params) |> Map.put(:action, :insert)
    socket |> assign(:modal, %{modal | changeset: changeset}) |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns
    params = Map.get(params, @key, %{})
    changeset = changeset.data |> @module.change(params) |> Map.put(:action, :insert)
    socket |> assign(:modal, %{modal | changeset: changeset}) |> save() |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
