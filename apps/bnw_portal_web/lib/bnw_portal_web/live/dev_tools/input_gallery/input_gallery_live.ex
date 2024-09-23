defmodule BnwPortalWeb.DevTools.InputGallery.InputGalleryLive do
  use BnwPortalWeb, :live_view

  defp set_modal(socket, modal \\ nil, id \\ nil)
  defp set_modal(socket, :on,   _id), do: socket |> assign(:modal, true)
  defp set_modal(socket, _, _), do: socket |> assign(:modal, false)

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:modal,      false)
    |> assign(:page_title, "Input Gallery")
    |> assign(:app,        "Temp")
    |> assign(:form,       %{})
    |> res(:ok)
  end

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("add_new", _, socket), do: socket |> set_modal(:on) |> res()

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    socket
    |> assign(:form, params)
    |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    res(socket)
  end
end
