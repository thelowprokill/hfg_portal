defmodule HfgPortalWeb.Home.HomeLive do
  use HfgPortalWeb, :live_view

  alias HfgPortal.Accounts

  defp can_see_dm_page(socket) do
    %{
      current_user: %{
        active:       active,
        generic_user: generic_user,
      }
    } = socket.assigns
    socket
    |> assign(:can_see_dm_page, active && !generic_user)
  end

  defp generate_token(socket) do
    %{current_user: %{id: user_id}} = socket.assigns

    token_config = Map.put(%{}, "scope", %Joken.Claim{
      generate: fn -> "user" end,
      validate: fn val, _claims, _context -> val in ["u", "a"] end
    })
    signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET"))

    {:ok, claims} = Joken.generate_claims(token_config, %{
      user_id:    user_id,
      admin:      false,
      updated_at: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%dT%H:%M:%S"),
    })
    {:ok, jwt, _claims} = Joken.encode_and_sign(claims, signer)
    socket
    |> assign(:jwt_token, jwt)
  end

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "HFG Portal", "Home")
    |> assign(:session, %{})
    |> handle_params(session)
    |> can_see_dm_page()
    |> generate_token()
    |> res(:ok)
  end

  defp handle_params(socket, %{"app" => app} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "app", app))
    |> handle_params(session |> Map.delete("app"))
  end
  defp handle_params(socket, %{"page" => page} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "page", page))
    |> handle_params(session |> Map.delete("page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do 
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "admin", admin))
    |> handle_params(session |> Map.delete("admin"))
  end
  defp handle_params(socket, _session), do: socket

  @impl true
  def handle_info({[:user, :updated], user}, socket) do
    %{current_user: current_user} = socket.assigns

    cond do
      current_user.id == user.id -> socket |> assign(:current_user, user)
      true -> socket
    end
    |> can_see_dm_page()
    |> res()
  end

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end
end
