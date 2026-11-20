defmodule HfgPortalWeb.Helpers.Modal do
  use Phoenix.LiveView

  import HfgPortalWeb.Helpers.Icons
  import HfgPortalWeb.Helpers.Utility
  import HfgPortalWeb.Helpers.Buttons, only: [bnw_button_cancel: 1, bnw_button_danger: 1]
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

  @doc """
  A delete box that only enables Delete once `key` (default `name`) is typed exactly,
  case-sensitive. The inner content is the warning message.

      <.bnw_confirm_delete_typed id="delete_plug" name={@plug.name} item="Plug name" event="delete">
        This permanently deletes the plug and everything in it.
      </.bnw_confirm_delete_typed>

  `event` is sent to the parent (or `target`) with `%{"value" => typed}`. Check the value again
  there before deleting: the disabled button is only a hint.
  """
  attr :id,     :string, required: true
  attr :name,   :string, required: true, doc: "what is being deleted, shown in the title"
  attr :key,    :string, default: nil,   doc: "what must be typed, if not the name"
  attr :item,   :string, default: "Name", doc: ~s(the input's label, e.g. "Plug name")
  attr :event,  :string, required: true, doc: ~s(called with %{"value" => typed})
  attr :target, :any,    default: nil,   doc: "phx-target for event, when the parent is a LiveComponent"
  attr :cancel, :string, default: "cancel"
  slot :inner_block, required: true
  def bnw_confirm_delete_typed(assigns) do
    ~H"""
    <.live_component module={HfgPortalWeb.Helpers.ConfirmDelete} id={@id} name={@name} key={@key} item={@item}
      event={@event} target={@target} cancel={@cancel} inner_block={@inner_block} />
    """
  end

  @doc """
  A plain delete box (no typing; for that see `bnw_confirm_delete_typed/1`): "Are you sure you
  want to delete <name>?", or just "Are you sure?" without a name, with Cancel and Delete.
  Inner content, if given, replaces the question.

      <.bnw_confirm_delete id="delete_row" name="this row" event="delete" values={%{id: row.id}} />

  Delete sends `event` with `values` as its params (to `target`, if set).
  """
  attr :id,     :string, required: true
  attr :name,   :string, default: nil,  doc: ~s(what is being deleted; without it the box just asks "Are you sure?")
  attr :event,  :any,    required: true, doc: "the event Delete sends; nil for none (the root layout's shared box, which app.js answers)"
  attr :values, :map,    default: %{},  doc: ~s(params sent with event, e.g. %{id: 5})
  attr :target, :any,    default: nil,  doc: "phx-target for event, when the parent is a LiveComponent"
  attr :cancel, :any,    default: "cancel", doc: "the cancel event; nil for none, as for event"
  slot :inner_block
  def bnw_confirm_delete(assigns) do
    assigns = assign(assigns, :phx_values, Map.new(assigns.values, fn {k, v} -> {"phx-value-#{k}", v} end))

    ~H"""
    <.bnw_modal id={"#{@id}_modal"} event={@cancel}>
      <%!-- data-confirm-delete-name: app.js fills these in for the layout's shared box. --%>
      <.bnw_modal_header>Delete <span data-confirm-delete-name><%= @name %></span></.bnw_modal_header>
      <.bnw_modal_body>
        <%= if @inner_block != [] do %>
          <%= render_slot(@inner_block) %>
        <% else %>
          <span data-confirm-delete-named class={@name in [nil, ""] && "hidden"}>Are you sure you want to delete <strong data-confirm-delete-name><%= @name %></strong>?</span>
          <span data-confirm-delete-unnamed class={@name not in [nil, ""] && "hidden"}>Are you sure?</span>
        <% end %>
      </.bnw_modal_body>
      <.bnw_modal_footer>
        <.bnw_button_cancel id={"#{@id}_cancel"} phx_click={@cancel} />
        <.bnw_button_danger id={"#{@id}_confirm"} phx_click={@event} phx-target={@target} {@phx_values}
          class="disabled:opacity-50 disabled:cursor-not-allowed">Delete</.bnw_button_danger>
      </.bnw_modal_footer>
    </.bnw_modal>
    """
  end

  attr :changeset, :map, required: true
  slot :inner_block
  def bnw_modal_new_or_edit(assigns), do: ~H'<%= if is_nil(@changeset.data.id), do: "New ", else: "Edit " %><%= render_slot(@inner_block) %>'

  def render(assigns), do: ~H"<div>render</div>"
end
