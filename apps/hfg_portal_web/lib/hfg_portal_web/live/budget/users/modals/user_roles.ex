defmodule HfgPortalWeb.Budget.Users.Modals.ChangeUserRoles do
  use HfgPortalWeb, :live_component

  @module Budget.UserRoles
  @key    "user_role"

  alias Budget.Users.Roles

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="user_role">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>User Access</.bnw_modal_new_or_edit></.bnw_modal_header>
        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <.bnw_input_hidden f={f} field={:user_id} value={@modal.opts.user_id} />
            <.bnw_input f={f} type="select" field={:role} display_name="Role" list={@roles} />

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
    |> assign(:roles, Roles.list() |> Enum.map(&[value: &1.name, key: &1.name]))
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
