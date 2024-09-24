defmodule HfgPortalWeb.Helpers.Buttons do
  use Phoenix.LiveView

  import HfgPortalWeb.Helpers.Icons

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

  # base button
  def bnw_button(assigns) do
    assigns =
      assigns
      |> assign(:class,     "py-2 px-6 rounded #{Map.get(assigns, :class, "")}")
      |> assign(:type,      Map.get(assigns, :type, "button"))
      |> assign(:phx_click, Map.get(assigns, :phx_click, ""))
    ~H"""
    <button phx-click={@phx_click} {exclude_items(assigns)}>
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  def bnw_button_icon(assigns) do
    assigns =
      assigns
      |> assign(:class,     "rounded #{Map.get(assigns, :class, "")}")
      |> assign(:type,      Map.get(assigns, :type, "button"))
      |> assign(:phx_click, Map.get(assigns, :phx_click, ""))

    ~H"""
    <button phx-click={@phx_click} {exclude_items(assigns)}>
      <.bnw_icon {exclude_items(assigns, [:data, :phx_click, :type])} />
    </button>
    """
  end

  def bnw_button_load_more(assigns) do
    assigns =
      assigns
      |> assign(:phx_click, Map.get(assigns, :phx_click, :load_more))
    ~H"""
    <span phx-hook="self_press_button" phx-click={@phx_click} {exclude_items(assigns)}></span>
    """
  end

  # admin
  def bnw_button_admin_pill(assigns) do
    assigns =
      assigns
      |> assign(:class, "rounded-full #{Map.get(assigns, :class, "")}")
    ~H"<.bnw_button_admin {assigns}/>"
  end

  def bnw_button_admin(assigns) do
    assigns =
      assigns
      |> assign(:class, "
        py-1
        px-3
        text-white
        ring-8
        ring-inset
        ring-danger-main
        bg-primary-main
        dark:success-main
        hover:bg-primary-hover
        focus:bg-primary-hover
        hover:ring-danger-hover
        focus:ring-danger-hover
        #{Map.get(assigns, :class, "")}
      ")
    ~H"<.bnw_button {assigns}/>"
  end

  # primary buttons
  def bnw_button_primary_pill(assigns) do
    assigns =
      assigns
      |> assign(:class, "rounded-full #{Map.get(assigns, :class, "")}")
    ~H"<.bnw_button_primary {assigns}/>"
  end

  def bnw_button_primary(assigns) do
    assigns =
      assigns
      |> assign(:class, "
        text-white
        bg-primary-main
        dark:success-main
        hover:bg-primary-hover
        focus:bg-primary-hover
        #{Map.get(assigns, :class, "")}
      ")
    ~H"<.bnw_button {assigns}/>"
  end

  # secondary buttons
  def bnw_button_secondary_pill(assigns) do
    assigns =
      assigns
      |> assign(:class, "rounded-full #{Map.get(assigns, :class, "")}")
    ~H"<.bnw_button_secondary {assigns}/>"
  end

  def bnw_button_secondary(assigns) do
    assigns =
      assigns
      |> assign(:class, "
        text-white
        bg-secondary-main
        hover:bg-secondary-hover
        focus:bg-secondary-hover
        #{Map.get(assigns, :class, "")}
      ")
    ~H"<.bnw_button {assigns}/>"
  end

  # success buttons
  def bnw_button_success_pill(assigns) do
    assigns =
      assigns
      |> assign(:class, "rounded-full #{Map.get(assigns, :class, "")}")
    ~H"<.bnw_button_success {assigns}/>"
  end

  def bnw_button_success(assigns) do
    assigns =
      assigns
      |> assign(:class, "
        text-white
        bg-success-main
        hover:bg-success-hover
        focus:bg-success-hover
        #{Map.get(assigns, :class, "")}
      ")
    ~H"<.bnw_button {assigns}/>"
  end

  # danger buttons
  def bnw_button_danger_pill(assigns) do
    assigns =
      assigns
      |> assign(:class, "rounded-full #{Map.get(assigns, :class, "")}")
    ~H"<.bnw_button_danger {assigns}/>"
  end

  def bnw_button_danger(assigns) do
    assigns =
      assigns
      |> assign(:class, "
        text-white
        bg-danger-main
        hover:bg-danger-hover
        focus:bg-danger-hover
        #{Map.get(assigns, :class, "")}
      ")
    ~H"<.bnw_button {assigns}/>"
  end

  # muted buttons
  def bnw_button_muted_pill(assigns) do
    assigns =
      assigns
      |> assign(:class, "rounded-full #{Map.get(assigns, :class, "")}")
    ~H"<.bnw_button_muted {assigns}/>"
  end

  def bnw_button_muted(assigns) do
    assigns =
      assigns
      |> assign(:class, "
        text-slate-700
        bg-muted-main
        border
        border-muted-main
        hover:bg-muted-hover
        focus:bg-muted-hover
        dark:text-white
        dark:bg-slate-800
        dark:border-slate-950
        dark:hover:bg-slate-700
        #{Map.get(assigns, :class, "")}
      ")
    ~H"<.bnw_button {assigns}/>"
  end

  # default buttons
  def bnw_button_default_pill(assigns) do
    assigns =
      assigns
      |> assign(:class, "rounded-full #{Map.get(assigns, :class, "")}")
    ~H"<.bnw_button_default {assigns}/>"
  end

  def bnw_button_default(assigns) do
    assigns =
      assigns
      |> assign(:class, "
        border
        border-gray-300
        bg-default-main
        hover:bg-default-hover
        focus:bg-default-hover
        dark:bg-zinc-900
        dark:hover:bg-zinc-700
        #{Map.get(assigns, :class, "")}
      ")
    ~H"<.bnw_button {assigns}/>"
  end

  # specific buttons
  def bnw_button_submit(assigns) do
    assigns =
      assigns
      |> assign(:type,        "submit")
      |> assign(:inner_block, Map.get(assigns, :inner_block, gen_inner_block("Save")))

    ~H"<.bnw_button_primary {assigns} />"
  end

  def bnw_button_new(assigns) do
    assigns =
      assigns
      |> assign(:inner_block, Map.get(assigns, :inner_block, gen_inner_block("Add New")))
      |> assign(:phx_click,   Map.get(assigns, :phx_click, :add_new))
      |> assign(:class,       "w-1/2 " <> Map.get(assigns, :class, ""))

    ~H"<.bnw_button_primary_pill {assigns} />"
  end

  def bnw_button_cancel(assigns) do
    assigns =
      assigns
      |> assign(:inner_block, Map.get(assigns, :inner_block, gen_inner_block("Cancel")))
      |> assign(:phx_click,   Map.get(assigns, :phx_click, :cancel))
    ~H"<.bnw_button_default {assigns} />"
  end

  def bnw_button_done(assigns) do
    assigns =
      assigns
      |> assign(:inner_block, Map.get(assigns, :inner_block, gen_inner_block("Done")))
      |> assign(:phx_click,   Map.get(assigns, :phx_click, :cancel))
    ~H"<.bnw_button_default {assigns} />"
  end

  def bnw_button_x(assigns) do
    assigns =
      assigns
      |> assign(:class,     "uk-modal-close-default " <> Map.get(assigns, :class, ""))
      |> assign(:phx_click, Map.get(assigns, :phx_click, :cancel))
      |> assign(:bnw_icon,  Map.get(assigns, :icon,      "x"))

    ~H"<.bnw_button_icon {assigns}/>"
  end

  def bnw_button_save(assigns) do
    assigns =
      assigns
      |> assign(:inner_block, Map.get(assigns, :inner_block, gen_inner_block("Save")))
      |> assign(:phx_click,   Map.get(assigns, :phx_click, :save))
    ~H"<.bnw_button_primary {assigns} />"
  end

  def bnw_button_edit(assigns) do
    assigns =
      assigns
      |> assign(:bnw_icon,  "edit")
      |> assign(:phx_click, Map.get(assigns, :phx_click, :edit))
    ~H"<.bnw_button_icon {assigns}/>"
  end

  def bnw_button_copy(assigns) do
    assigns =
      assigns
      |> assign(:bnw_icon, "copy")
      |> assign(:phx_click, Map.get(assigns, :phx_click, :copy))
    ~H"<.bnw_button_icon {assigns}/>"
  end

  def bnw_button_delete(assigns) do
    assigns =
      assigns
      |> assign(:bnw_icon,  "delete")
      |> assign(:phx_click, Map.get(assigns, :phx_click, :delete))
      |> assign(:class,     "text-danger-main hover:text-danger-hover #{Map.get(assigns, :class, "")}")
      |> assign(:data,      Map.get(assigns, :data, [confirm: "Are you sure"]))
    ~H"<.bnw_button_icon {assigns}/>"
  end

  # icon buttons
  def bnw_button_up(assigns) do
    assigns =
      assigns
      |> assign(:bnw_icon,  "chevron-up")
      |> assign(:phx_click, Map.get(assigns, :phx_click, :move_up))
      |> assign(:class,     "text-primary-main" <> Map.get(assigns, :class, ""))
    ~H"<.bnw_button_icon {assigns}/>"
  end

  def bnw_button_down(assigns) do
    assigns =
      assigns
      |> assign(:bnw_icon,  "chevron-dn")
      |> assign(:phx_click, Map.get(assigns, :phx_click, :move_dn))
      |> assign(:class,     "text-primary-main" <> Map.get(assigns, :class, ""))
    ~H"<.bnw_button_icon {assigns}/>"
  end

  def bnw_button_tab(assigns) when assigns.selected do
    assigns =
      assigns
      |> assign(:class, "p-2 px-4 bg-primary-main rounded-none rounded-t-xl text-white " <> Map.get(assigns, :class, ""))
    ~H"<.bnw_button {assigns} />"
  end
  def bnw_button_tab(assigns) do
    assigns =
      assigns
      |> assign(:class, "p-2 px-4 hover:bg-primary-hover rounded-none rounded-t-xl" <> Map.get(assigns, :class, ""))
    ~H"<.bnw_button {assigns} />"
  end

  def bnw_button_toggle_active(assigns) when not assigns.edit and assigns.active, do: ~H"<.bnw_icon class='text-success-main' bnw_icon='check'/>"
  def bnw_button_toggle_active(assigns) when not assigns.edit, do: ~H"<.bnw_icon class='text-danger-main' bnw_icon='ban'/>"
  def bnw_button_toggle_active(assigns) when assigns.active do 
    assigns = 
      assigns
      |> assign(:class,     "text-success-main hover:text-success-hover" <> Map.get(assigns, :class, ""))
      |> assign(:phx_click, Map.get(assigns, :phx_click_deactivate, "deactivate"))
      |> assign(:bnw_icon,  Map.get(assigns, :bnw_icon_active, "check"))
    ~H"<.bnw_button_icon {assigns} />"
  end
  def bnw_button_toggle_active(assigns) do 
    assigns = 
      assigns
      |> assign(:class,     "text-danger-main hover:text-danger-hover" <> Map.get(assigns, :class, ""))
      |> assign(:phx_click, Map.get(assigns, :phx_click_activate, "activate"))
      |> assign(:bnw_icon,  Map.get(assigns, :bnw_icon_inactive, "ban"))
    ~H"<.bnw_button_icon {assigns} />"
  end

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  defp gen_inner_block(text), do: [%{__slot__: :inner_block, inner_block: fn _, _ -> text end}]
end
