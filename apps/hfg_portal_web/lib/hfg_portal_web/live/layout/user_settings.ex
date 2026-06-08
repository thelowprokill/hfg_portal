defmodule HfgPortalWeb.Layout.UserSettings do
  use HfgPortalWeb, :live_component

  alias HfgPortal.Accounts

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

              <div class="flex">
                <.bnw_button_copy 
                  id="copy_jwt_token"
                  phx_click="copy_jwt"
                  phx-hook="copy_to_clipboard"
                  phx-target={@myself}
                />
                <div class="w-full cursor-pointer" phx-click="copy_jwt" phx-target={@myself} style="overflow-wrap: anywhere;">
                  <%= @modal |> Map.get(:opts, %{}) |> Map.get(:jwt) %>
                </div>
              </div>

          </.bnw_modal_body>

          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit/></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  def generate_token(socket) do
    %{modal: %{user: %{id: user_id}}} = socket.assigns
    token_config = Map.put(%{}, "scope", %Joken.Claim{
      generate: fn -> "user" end,
      validate: fn val, _claims, _context -> val in ["u", "a"] end
    })
    signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET"))

    {:ok, claims} = Joken.generate_claims(token_config, %{
      user_id:    user_id,
      updated_at: DateTime.utc_now(),
    })
    {:ok, jwt, _claims} = Joken.encode_and_sign(claims, signer)
    socket
    |> assign(:jwt, jwt)
  end

  @impl true
  def update(assigns, socket) do
    changeset = assigns.modal.user |> Accounts.change_self_user()
    socket
    |> assign(assigns)
    |> generate_token()
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
  def handle_event("copy_jwt", _, socket) do
    %{jwt: jwt} = socket.assigns
    
    socket
    |> push_event("copy_to_clipboard", %{text: jwt})
    |> put_flash(:info, "JWT token copied to clipboard")
    |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__ |> to_string())
    socket |> res()
  end
end
