defmodule HfgPortalWeb.Helpers.ConfirmDelete do
  @moduledoc """
  A delete confirmation box: Delete stays disabled until the key is typed exactly (case-sensitive).
  Use it through `HfgPortalWeb.Helpers.Modal.bnw_confirm_delete_typed/1`.

  It only checks the typing to enable the button. The parent's `event` gets
  `%{"value" => typed}` and must check it again before deleting.
  """
  use HfgPortalWeb, :live_component

  alias Phoenix.LiveView.JS

  # Typing comes here (to enable Delete); the submit goes to the parent, or to `target`.
  @impl true
  def mount(socket), do: socket |> assign(:typed, "") |> res(:ok)

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :key, assigns.key || assigns.name)

    ~H"""
    <div>
      <.bnw_modal id={"#{@id}_modal"} event={@cancel}>
        <.bnw_modal_header>Delete <%= @name %></.bnw_modal_header>
        <.form :let={f} for={to_form(%{"value" => @typed}, as: :confirm)} id={"#{@id}_form"}
          phx-change={JS.push("typed", target: @myself)} phx-submit={@event} phx-target={@target}>
          <.bnw_modal_body>
            <div class="pb-3"><%= render_slot(@inner_block) %></div>
            <p>Type <strong class="select-all"><%= @key %></strong> to confirm.</p>
            <.bnw_input f={f} field={:value} name="value" display_name={"#{@item} (case-sensitive)"} debounce="100" autocomplete="off" />
          </.bnw_modal_body>
          <.bnw_modal_footer>
            <.bnw_button_cancel id={"#{@id}_cancel"} phx_click={@cancel} />
            <.bnw_button_danger id={"#{@id}_confirm"} type="submit" disabled={@typed != @key}
              class="disabled:opacity-50 disabled:cursor-not-allowed">Delete</.bnw_button_danger>
          </.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  @impl true
  def handle_event("typed", %{"value" => typed}, socket), do: socket |> assign(:typed, typed) |> res()
end
