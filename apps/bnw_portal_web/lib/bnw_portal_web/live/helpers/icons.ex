defmodule BnwPortalWeb.Helpers.Icons do
  use Phoenix.LiveView

  # To add new icons go to https://heroicons.com/ and copy the svg
  # create a new bnw_icno function setting the bnw_icon property to the name of the icon
  # paste the svg


  #We cannot think of a better solution at the moment.
  #Give us a better solution.
  #It cannot render when there is a map in assigns.
  #this removes auto generated maps from the assigns struct
  #If it complains about "protocol Phoenix.HTML.Safe not implemented for..." 
  #add the key to this list.
  @exclude_keys [
    :__meta__,
    :__struct__,
    :__changed__,
    :inner_block,
    :phx_click,
  ]

  defp exclude_items(assigns, keys), do: assigns |> Map.drop(keys)
  defp exclude_items(assigns), do: assigns |> exclude_items(@exclude_keys)

  defp make_bnw_icon(assigns) do
    assigns =
      assigns
      |> assign(:class,       "w-6 h-6 #{Map.get(assigns, :class, "")}")
      |> assign(:fill,        Map.get(assigns, :fill,        "none"))
      |> assign(:stroke,      Map.get(assigns, :stroke,      "currentColor"))
      |> assign(:strokeWidth, Map.get(assigns, :strokeWidth, "1.5"))
      |> assign(:viewBox,     Map.get(assigns, :viewBox,     "0 0 24 24"))
    ~H"""
      <svg xmlns="http://www.w3.org/2000/svg" {assigns |> exclude_items}>
        <%= render_slot(@inner_block) %>
      </svg>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "arrow-path" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path d="M4.755 10.059a7.5 7.5 0 0 1 12.548-3.364l1.903 1.903h-3.183a.75.75 0 1 0 0 1.5h4.992a.75.75 0 0 0 .75-.75V4.356a.75.75 0 0 0-1.5 0v3.18l-1.9-1.9A9 9 0 0 0 3.306 9.67a.75.75 0 1 0 1.45.388Zm15.408 3.352a.75.75 0 0 0-.919.53 7.5 7.5 0 0 1-12.548 3.364l-1.902-1.903h3.183a.75.75 0 0 0 0-1.5H2.984a.75.75 0 0 0-.75.75v4.992a.75.75 0 0 0 1.5 0v-3.18l1.9 1.9a9 9 0 0 0 15.059-4.035.75.75 0 0 0-.53-.918Z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "ban" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "check" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-double-dn" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 5.25l-7.5 7.5-7.5-7.5m15 6l-7.5 7.5-7.5-7.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-double-lt" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M18.75 19.5l-7.5-7.5 7.5-7.5m-6 15L5.25 12l7.5-7.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-double-rt" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M11.25 4.5l7.5 7.5-7.5 7.5m-6-15l7.5 7.5-7.5 7.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-double-up" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l7.5-7.5 7.5 7.5m-15 6l7.5-7.5 7.5 7.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-dn" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-lt" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-rt" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-up" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75l7.5-7.5 7.5 7.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-up-dn" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 10.75l7.5-7.5 7.5 7.5" />
        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 15.25l-7.5 7.5-7.5-7.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-up-solid" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path fill="currentColor" stroke-linecap="round" stroke-linejoin="round" d="M4.5 15.75h15l-7.5-7.5-7.5 7.5z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "chevron-dn-solid" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path fill="currentColor" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" d="M19.5 8.25l-7.5 7.5-7.5-7.5h15z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "copy" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "delete" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "download" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m.75 12l3 3m0 0l3-3m-3 3v-6m-1.5-9H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "edit" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L6.832 19.82a4.5 4.5 0 01-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 011.13-1.897L16.863 4.487zm0 0L19.5 7.125" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "hamburger" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "lock" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "minus" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M5 12h14" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "moon" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "plus" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "plus-circle" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v6m3-3H9m12 0a9 9 0 11-18 0 9 9 0 0118 0z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "search" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "settings" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z" />
        <path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "sign-out" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 9V5.25A2.25 2.25 0 0013.5 3h-5a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 007.5 21h6a2.25 2.25 0 002.25-2.25V15m3 0l3-3m0 0l-3-3m3 3H9" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "star" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M11.48 3.499a.562.562 0 0 1 1.04 0l2.125 5.111a.563.563 0 0 0 .475.345l5.518.442c.499.04.701.663.321.988l-4.204 3.602a.563.563 0 0 0-.182.557l1.285 5.385a.562.562 0 0 1-.84.61l-4.725-2.885a.562.562 0 0 0-.586 0L6.982 20.54a.562.562 0 0 1-.84-.61l1.285-5.386a.562.562 0 0 0-.182-.557l-4.204-3.602a.562.562 0 0 1 .321-.988l5.518-.442a.563.563 0 0 0 .475-.345L11.48 3.5Z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "sun" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path strokeLinecap="round" strokeLinejoin="round" d="M12 3v2.25m6.364.386l-1.591 1.591M21 12h-2.25m-.386 6.364l-1.591-1.591M12 18.75V21m-4.773-4.227l-1.591 1.591M5.25 12H3m4.227-4.773L5.636 5.636M15.75 12a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "unlock" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M13.5 10.5V6.75a4.5 4.5 0 119 0v3.75M3.75 21.75h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H3.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "upload" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m6.75 12l-3-3m0 0l-3 3m3-3v6m-1.5-15H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) when assigns.bnw_icon == "x" do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
      </.make_bnw_icon>
    """
  end

  def bnw_icon(assigns) do
    ~H"""
      <.make_bnw_icon {assigns} >
        <path stroke-linecap="round" stroke-linejoin="round" d="M15.182 16.318A4.486 4.486 0 0012.016 15a4.486 4.486 0 00-3.198 1.318M21 12a9 9 0 11-18 0 9 9 0 0118 0zM9.75 9.75c0 .414-.168.75-.375.75S9 10.164 9 9.75 9.168 9 9.375 9s.375.336.375.75zm-.375 0h.008v.015h-.008V9.75zm5.625 0c0 .414-.168.75-.375.75s-.375-.336-.375-.75.168-.75.375-.75.375.336.375.75zm-.375 0h.008v.015h-.008V9.75z" />
      </.make_bnw_icon>
    """
  end

  # make the compiler happy
  def render(assigns), do: ~H"<div>render</div>"
end
