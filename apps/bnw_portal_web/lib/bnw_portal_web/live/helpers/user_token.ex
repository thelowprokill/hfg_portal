defmodule BnwPortalWeb.Helpers.UserToken do
  use Phoenix.LiveView


  def bnw_verify_user_token(socket, session, app \\ "", page \\ "")
  def bnw_verify_user_token(socket, %{"user_token" => user_token} = session, app, page) do
    user = 
      BnwPortal.Accounts.get_user_by_session_token(user_token)
      |> Map.put(:admin_mode, Map.get(session, "admin", "false") == "true")
    
    cond do
      user && app  != "" && page != "" -> assign(socket, current_user: user) |> assign(:page_title, "#{app} · #{page}")
      user && app  != ""               -> assign(socket, current_user: user) |> assign(:page_title, "#{app}")
      user && page != ""               -> assign(socket, current_user: user) |> assign(:page_title, "#{page}")
      user                             -> assign(socket, current_user: user) |> assign(:page_title, "Bnw Portal")
      true -> redirect(socket, to: "/users/log_in")
    end
  end

  def bnw_verify_user_token(socket, _session, _app, _page) do
    redirect(socket, to: "/users/log_in")
  end

  def bnw_verify_user_token_side_bar(socket, session, page_title \\ "")
  def bnw_verify_user_token_side_bar(socket, %{"user_token" => user_token}, page_title) do
    socket
    |> assign(current_user: BnwPortal.Accounts.get_user_by_session_token(user_token))
    |> assign(:page_title, page_title)
  end

  def bnw_verify_user_token_side_bar(socket, _session, _page_title) do
    assign(socket, current_user: nil)
  end

  # make the compiler happy
  def render(assigns), do: ~H"<div>render</div>"
end

