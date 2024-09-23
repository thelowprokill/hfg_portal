defmodule BnwPortalWeb.Budget.Home.Modals.ChangeDrafts do
  use BnwPortalWeb, :live_component

  @module Budget.Drafts
  @key "draft_edit"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="company_modal">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>Draft</.bnw_modal_new_or_edit></.bnw_modal_header>
        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <.bnw_input_hidden f={f} field={:company_budget_id} value={@modal.opts.selected.budget} />
            <.bnw_input_hidden f={f} field={:starting_month}    value={@modal.opts.starting_month} />

            <.bnw_input f={f} field={:draft_type_id}     display_name="Draft Type" type="select" list={@modal.opts.draft_types |> Enum.map(&([key: &1.name, value: &1.id]))} />
            <.bnw_input f={f} field={:name}              display_name="Name" />
            <.bnw_input f={f} field={:year}              display_name="Year" />
            <.bnw_input f={f} field={:previous_draft_id} display_name="Previous Draft" type="select" list={[]} />

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
            IO.inspect(changeset.errors)
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

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end


