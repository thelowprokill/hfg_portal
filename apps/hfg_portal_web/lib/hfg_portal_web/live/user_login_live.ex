defmodule HfgPortalWeb.UserLoginLive do
  use HfgPortalWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm dark:bg-zinc-900">
      <div class="p-3 flex justify-center hidden dark:block">
        <!-- this is apps/hfg_portal_web/priv/static/images/bnw_logo_white.svg -->
        <img src={"/images/#{System.get_env("LOCATION") || "bnw"}_logo_white.svg"} width="300" />
      </div>
      <div class="p-3 flex justify-center dark:hidden">
        <!-- this is apps/hfg_portal_web/priv/static/images/bnw_logo.svg -->
        <img src={"/images/#{System.get_env("LOCATION") || "bnw"}_logo.svg"} width="300" />
      </div>

      <hr>
      <.header class="text-center">
        Sign in to account
      </.header>

      <.simple_form for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
        <.input field={@form[:username]} label="Username" required />
        <.input field={@form[:password]} type="password" label="Password" required />

        <:actions>
          <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
          <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
            Forgot your password?
          </.link>
        </:actions>
        <:actions>
          <.bnw_button_primary_pill phx-disable-with="Signing in..." type="submit" class="w-full">
            Sign in <span aria-hidden="true">→</span>
          </.bnw_button_primary_pill>
        </:actions>
      </.simple_form>
      <div class="text-center text-sm mt-4 pb-3">
          or
      </div>
      <div>
        <.link href={@google_auth_url}>
          <.bnw_button_primary_pill phx-disable-with="Signing in..." class="w-full flex justify-center">
            <span aria-hidden="true" class="mr-2">
              <svg width="20" height="20" viewBox="0 0 20 20">
                <path d="M17.86,9.09 C18.46,12.12 17.14,16.05 13.81,17.56 C9.45,19.53 4.13,17.68 2.47,12.87 C0.68,7.68 4.22,2.42 9.5,2.03 C11.57,1.88 13.42,2.37 15.05,3.65 C15.22,3.78 15.37,3.93 15.61,4.14 C14.9,4.81 14.23,5.45 13.5,6.14 C12.27,5.08 10.84,4.72 9.28,4.98 C8.12,5.17 7.16,5.76 6.37,6.63 C4.88,8.27 4.62,10.86 5.76,12.82 C6.95,14.87 9.17,15.8 11.57,15.25 C13.27,14.87 14.76,13.33 14.89,11.75 L10.51,11.75 L10.51,9.09 L17.86,9.09 L17.86,9.09 Z">
                </path>
              </svg>
            </span>
            <p>Sign in with Google</p>
          </.bnw_button_primary_pill>
        </.link>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    username = live_flash(socket.assigns.flash, :username)
    form = to_form(%{"username" => username}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end

  @impl true
  def handle_params(params, url, socket) do
    base_url =
      case Application.get_env(:hfg_portal_web, :environment) do
        "production" ->
          HfgPortalWeb.Endpoint.url()
          |> String.replace("http:", "https:")
          |> String.replace(":4000", "")
        _ ->
          HfgPortalWeb.Endpoint.url()
      end
    socket =
      socket
      |> assign(:url, url)
      |> assign(:params, params)
      |> assign(:google_auth_url, ElixirAuthGoogle.generate_oauth_url(base_url))

    {:noreply, socket}
  end
end
