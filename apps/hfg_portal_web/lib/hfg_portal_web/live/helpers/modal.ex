defmodule HfgPortalWeb.Helpers.Modal do
  use Phoenix.LiveView

  import HfgPortalWeb.Helpers.Icons
  import HfgPortalWeb.Helpers.Utility
  #import HfgPortalWeb.Helpers.Reports

  attr :modal_stack, :list, required: true
  attr :socket,      :map,  required: true
  attr :reports,     :list, default: []
  def bnw_modal_render(assigns) do
    ~H"""
      <% modal = stack_tail(@modal_stack) %>
      <%= cond do 
        modal && Map.get(modal, :modal) == :report ->
          HfgPortalWeb.Helpers.Reports.bnw_report(Map.get(modal.opts, :report))
        modal && Map.get(modal, :modal) == :pick_reports ->
          HfgPortalWeb.Helpers.Reports.bnw_report_picker(%{reports: @reports, modal: modal})
        modal && Map.get(modal, :live, false) -> 
          live_render(
            @socket,
            modal.module, 
            id: "modal_#{modal.modal}_#{modal.id}",
            session: %{"modal" => modal, "parent" => self()}
          )
        modal -> 
          live_component(%{
            module: modal.module, 
            id: "modal_#{modal.modal}_#{modal.id}",
            modal: modal
          })
        true -> nil
      end %>
    """
  end

  attr :id,      :string, required: true
  attr :event,   :string, default: "cancel"
  attr :width,   :string, default: "w-5/12"
  attr :opacity, :boolean, default: true
  slot :inner_block, required: true
  def bnw_modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="relative z-50"
    >
      <%= if @opacity do %>
        <div id={"#{@id}-bg"} class="bg-zinc-50/90 dark:bg-zinc-700/90 fixed inset-0 transition-opacity" aria-hidden="true" />
      <% end %>
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full w-full items-center justify-center">
          <div class={"p-4 sm:p-6 lg:py-8 #{@width}"}>
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={@event}
              phx-key="escape"
              phx-click-away={@event}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative rounded-2xl bg-white p-14 shadow-lg ring-1 transition dark:bg-zinc-800 dark:text-white"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={@event}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label="close"
                >
                  <.bnw_icon bnw_icon="x" class="h-5 w-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                <%= render_slot(@inner_block) %>
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  slot :inner_block
  def bnw_modal_header(assigns) do
    ~H"""
    <div class="flex items-start justify-between p-4 border-b rounded-t dark:border-gray-600">
      <h3 class="text-xl font-semibold">
        <%= render_slot(@inner_block) %>
      </h3>
    </div>
    """
  end

  attr :height, :integer, default: 65
  slot :inner_block
  def bnw_modal_body(assigns) do
    ~H"""
    <div class="p-6 overflow-auto"
         style={"max-height: #{@height}vh;"}>
        <%= render_slot(@inner_block) %>
    </div>
    """
  end

  slot :inner_block
  def bnw_modal_footer(assigns) do
    ~H"""
    <div class="flex justify-end pt-6 pb-0 space-x-2 border-t border-gray-200 rounded-b dark:border-gray-600">
        <%= render_slot(@inner_block) %>
    </div>
    """
  end

  attr :changeset, :map, required: true
  slot :inner_block
  def bnw_modal_new_or_edit(assigns), do: ~H"<%= if is_nil(@changeset.data.id), do: 'New ', else: 'Edit ' %><%= render_slot(@inner_block) %>"

  def render(assigns), do: ~H"<div>render</div>"
end
