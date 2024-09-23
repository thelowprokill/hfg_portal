defmodule BnwPortalWeb.Budget.Home.Components.Reports do
  use BnwPortalWeb, :live_component

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :reports, :list, required: true
  def reports(assigns) do
    ~H"""
      <div class="w-full">
        <div class="p-1 flex flex-col">
          <%= for report <- @reports do %>
            <div><.bnw_button phx_click="reports" phx-value-id={report.id}><%= report.report_name %></.bnw_button></div>
          <% end %>
          <div class="w-full"/>
        </div>
      </div>
    """
  end
end

