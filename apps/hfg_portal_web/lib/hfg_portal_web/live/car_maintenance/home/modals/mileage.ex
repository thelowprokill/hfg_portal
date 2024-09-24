defmodule HfgPortalWeb.CarMaintenance.Home.Modals.ChangeMileage do
  use HfgPortalWeb, :live_component

  @module CarMaintenance.ServiceHistories
  @key "service_history"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="car">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>Car</.bnw_modal_new_or_edit></.bnw_modal_header>
        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <%= if @modal.id == :new do %>
              <.bnw_input_hidden f={f} field={:created_by_id} value={@modal.user.id} />
            <% end %>
            <.bnw_input_hidden f={f} field={:updated_by_id} value={@modal.user.id} />
            <.bnw_input_hidden f={f} field={:car_id} value={@modal.opts.car_id} />

            <.bnw_input f={f} field={:service_date} type="date" display_name="Mileage Date" />
            <.bnw_input f={f} field={:mileage} type="number" display_name="Mileage" step="1"/>

          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit/></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
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
  def mount(socket), do: socket |> res(:ok)

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


