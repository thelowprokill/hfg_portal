defmodule HfgPortalWeb.UserLoginLive do
  use HfgPortalWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm dark:bg-zinc-900">
      <div class="p-3 flex justify-center">
        <img src={"/images/rook_logo.svg"} width="200" />
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
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    username = Phoenix.Flash.get(socket.assigns.flash, :username)
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
