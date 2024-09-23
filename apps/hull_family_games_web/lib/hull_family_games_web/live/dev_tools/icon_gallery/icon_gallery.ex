defmodule HullFamilyGamesWeb.DevTools.IconGallery.IconGallery do
  use HullFamilyGamesWeb, :live_view

  defp icon_list(socket) do
    assign(socket, :icons, [
      "arrow-path",
      "ban",
      "check",
      "chevron-double-dn",
      "chevron-double-lt",
      "chevron-double-rt",
      "chevron-double-up",
      "chevron-dn",
      "chevron-lt",
      "chevron-up",
      "chevron-up-solid",
      "chevron-dn-solid",
      "chevron-up-dn",
      "copy",
      "delete",
      "download",
      "edit",
      "hamburger",
      "lock",
      "moon",
      "plus",
      "plus-circle",
      "search",
      "settings",
      "sign-out",
      "star",
      "star-solid",
      "sun",
      "unlock",
      "upload",
      "x",
      "error"
    ])
  end

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign(:page_title, "Icon Gallery")
    |> assign(:app,        "Temp")
    |> icon_list()
    |> res(:ok)
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    res(socket)
  end
end
