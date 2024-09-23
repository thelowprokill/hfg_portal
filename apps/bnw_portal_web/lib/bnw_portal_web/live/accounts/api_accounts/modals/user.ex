defmodule BnwPortalWeb.Accounts.ApiAccounts.Modals.ChangeApiAccounts do
  use BnwPortalWeb, :live_component

  @module BnwPortal.ApiAccounts
  @key "api_user"

  alias BnwPortal.Locations

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="accounts_modal">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>Account</.bnw_modal_new_or_edit></.bnw_modal_header>
        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <.bnw_input_hidden f={f} field={:user_id} value={@modal.user.id} />

            <.bnw_input        f={f} field={:username}         display_name="Username"/>
            <.bnw_input_naked  f={f} field={:active}           display_name="Active"           type="checkbox"/>

            <.bnw_input        f={f} field={:password}         display_name="Password"         type="password" />
            <.bnw_input        f={f} field={:password_confirm} display_name="Password Confirm" type="password" />

          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit/></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  defp fetch_locations(socket) do
    socket
    #|> assign(:locationss, [])
    |> assign(:locations, Locations.list(%{active: true}))
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
    |> fetch_locations()
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

