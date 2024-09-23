defmodule BnwPortalWeb.Layout.UserSettings do
  use BnwPortalWeb, :live_component

  alias BnwPortal.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="user_settings">
        <.bnw_modal_header>Change User Settings</.bnw_modal_header>

        <.form :let={f} 
            for={@changeset} 
            phx-change="validate" 
            phx-submit="save" 
            phx-target={@myself}>
          <.bnw_modal_body>
            <%= @modal.user.email %>

              <.bnw_input       f={f} field={:first_name}       display_name="First Name" />
              <.bnw_input       f={f} field={:middle_name}      display_name="Middle Name" />
              <.bnw_input       f={f} field={:last_name}        display_name="Last Name" />
              <!--
              <.bnw_input       f={f} field={:email}            display_name="Email" />
              <.bnw_input       f={f} field={:username}         display_name="Username" />
              <.bnw_input_naked f={f} field={:active}           display_name="Active"           type="checkbox" />
              <.bnw_input_naked f={f} field={:portal_admin}     display_name="Portal Admin"     type="checkbox" />
              <.bnw_input_naked f={f} field={:dev_admin}        display_name="Dev Admin"        type="checkbox" />
              <.bnw_input_naked f={f} field={:test_user}        display_name="Test User"        type="checkbox" />
              <.bnw_input_naked f={f} field={:generic_user}     display_name="Generic User"     type="checkbox" />
              <.bnw_input       f={f} field={:attempted_login}  display_name="Attempted Login"  type="number" />
              <.bnw_input       f={f} field={:confirmed_at}     display_name="Confirmed At"     type="datetime-local" />
              <.bnw_input       f={f} field={:start_date}       display_name="Start Date"       type="datetime-local" />
              <.bnw_input       f={f} field={:end_date}         display_name="End Date"         type="datetime-local" />
              -->
              <.bnw_input       f={f} field={:password}         display_name="Password"         type="password" />
              <.bnw_input       f={f} field={:password_confirm} display_name="Password Confirm" type="password" />

          </.bnw_modal_body>

          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit/></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    changeset = assigns.modal.user |> Accounts.change_self_user()
    socket
    |> assign(assigns)
    |> assign(:changeset, changeset)
    |> res(:ok)
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    socket
    |> assign(:changeset, Accounts.change_self_user(socket.assigns.changeset.data, params) |> Map.put(:action, :insert))
    |> res()
  end

  @impl true
  def handle_event("save", %{"user" => params}, socket) do
    cond do
      socket.assigns.changeset.valid? ->
        Accounts.create_or_update_user(socket.assigns.changeset.data, params)
        |> case do
          {:ok, _} ->
            send(self(), :cancel)
            socket |> res()
          {:error, %Ecto.Changeset{} = changeset} ->
            socket |> assign(:changeset, changeset) |> res()
        end
      true -> socket |> res()
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__ |> to_string())
    socket |> res()
  end
end
