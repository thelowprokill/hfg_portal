defmodule HfgPortalWeb.Helpers.Reports do
  use Phoenix.LiveView

  import HfgPortalWeb.Helpers.Modal
  import HfgPortalWeb.Helpers.Buttons

  attr :id,          :string, required: true
  attr :report_url,  :string, required: true
  attr :report_name, :string, required: true
  attr :event,       :string, default: "cancel"
  attr :width,       :string, default: "w-5/6"
  attr :height,      :string, default: "70vh"
  def bnw_report(assigns) do
    ~H"""
    <div>
      <.bnw_modal id={"report_#{@id}"} width={@width}>
        <.bnw_modal_header><%= @report_name %></.bnw_modal_header>
        <iframe src={@report_url} style={"width: 100%; height: #{@height};"}></iframe>
        <.bnw_modal_footer><.bnw_button_done /></.bnw_modal_footer>
      </.bnw_modal>
    </div>
    """
  end

  #attr :id,          :string, required: true
  attr :modal,       :map
  attr :reports,     :list,   required: true
  attr :title,       :string, default: "Reports"
  attr :event,       :string, default: "reports"
  attr :cancel,      :string, default: "cancel"
  def bnw_report_picker(assigns) do
    ~H"""
    <div>
      <.bnw_modal id={"report_picker"}>
        <.bnw_modal_header><%= @title %></.bnw_modal_header>
        <.bnw_modal_body>
          <div>
            <%= for report <- @reports do %>
              <.bnw_button_primary phx_click={@event} phx-value-id={report.id} class="w-full m-2">
                <%= report.report_name %>
              </.bnw_button_primary>
              <br />
            <% end %>
          </div>
        </.bnw_modal_body>
        <.bnw_modal_footer><.bnw_button_done /></.bnw_modal_footer>
      </.bnw_modal>
    </div>
    """
  end


  # this is here just for the compiler
  def render(assigns), do: ~H"<div>render</div>"
end
