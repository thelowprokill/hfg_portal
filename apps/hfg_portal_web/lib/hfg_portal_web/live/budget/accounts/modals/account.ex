defmodule HfgPortalWeb.Budget.Accounts.Modals.ChangeAccount do
  use HfgPortalWeb, :live_component

  @module Budget.Accounts
  @key "account"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="account">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>Account</.bnw_modal_new_or_edit></.bnw_modal_header>

        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <.bnw_input_hidden f={f} field={:user_id} value={@modal.user.id} />

            <.bnw_input f={f} field={:name} display_name="Name" />
            <.bnw_input f={f}
              field={:type}
              type="select"
              display_name="Type"
              list={[[key: "Debit", value: "debit"], [key: "Credit", value: "credit"]]} />

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
        {:ok, _} -> cancel(socket)
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
