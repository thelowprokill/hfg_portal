defmodule BnwPortalWeb.Helpers.Expand do
  use Phoenix.LiveView

  import BnwPortalWeb.Helpers.{
    Buttons,
    Icons,
  }

  attr :name,     :string,  required: true
  attr :expanded, :boolean, required: true
  attr :click,    :string,  required: true
  attr :click_id, :integer, default:  0
  slot :inner_block,        required: true
  def bnw_expand(assigns) do
    ~H"""
      <div class="p-1 w-[90%] px-4 mx-4">
        <.bnw_button phx_click={@click} phx-value-id={@click_id} class="w-full">
          <div class="p-1 w-full flex">
            <%= @name %>
            <div class="flex-grow"></div>
            <.bnw_icon bnw_icon={if @expanded, do: "minus", else: "plus"} />
          </div>
        </.bnw_button>
        <div hidden={!@expanded}>
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    """
  end

  # make the compiler happy
  def render(assigns), do: ~H"<div>render</div>"
end



