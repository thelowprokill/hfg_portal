defmodule HfgPortalWeb.DevTools.ButtonGallery.ButtonGalleryLive do
  use HfgPortalWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    socket
    |> bnw_verify_user_token(session)
    |> assign(:page_title, "Button Gallery")
    |> assign(:app,        "Temp")
    |> res(:ok)
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    res(socket)
  end
end

