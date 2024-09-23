defmodule HullFamilyGamesWeb.Helpers.Display do
  use Phoenix.LiveView

  import HullFamilyGamesWeb.Helpers.Icons

  attr :value, :boolean, required: true
  def bnw_display_boolean(assigns) do
    ~H"""
    <%= if @value do %>
      <.bnw_icon bnw_icon="check" class="text-green-500" />
    <% else %>
      <.bnw_icon bnw_icon="ban"   class="text-red-500" />
    <% end %>
    """
  end


  # make the compiler happy
  def render(assigns), do: ~H"<div>render</div>"
end
