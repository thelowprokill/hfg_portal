defmodule HullFamilyGamesWeb.Home.HomeLive do
  use HullFamilyGamesWeb, :live_view

  alias HullFamilyGames.Accounts

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

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "#{(System.get_env("LOCATION") || "bnw") |> String.upcase} Portal", "Home")
    |> assign(:session, %{})
    |> handle_params(session)
    |> can_see_dm_page()
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
