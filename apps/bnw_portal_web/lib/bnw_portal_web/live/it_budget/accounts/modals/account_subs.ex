defmodule BnwPortalWeb.ItBudget.Accounts.Modals.ChangeAccountSubs do
  use BnwPortalWeb, :live_view

  alias ItBudget.{
    Repo
  }

  @module ItBudget.AccountSubs
  @key    "account_sub"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="account_sub_modal">
        <.bnw_modal_header><%= @modal.account.name %> - Subs</.bnw_modal_header>
        <.bnw_modal_body>
          <.form :let={f}
            for={@changeset}
            phx-change="validate"
            phx-submit="save">
            <.bnw_table height="60vh" id="account_subs_table">
              <:header>
                <th class="p-2">Sub</th>
                <th class="p-2">Description</th>
                <th class="p-2">Active</th>
                <th class="p-2"></th>
                <th class="p-2"></th>
              </:header>

              <tr id="new_item"><%= if @new do %><.edit_form f={f} account_id={@account_id} user_id={@modal.user.id} /><% end %></tr>

              <%= for item <- @items do %>
                <tr id={"item_#{item.id}"}>
                  <%= cond do %>
                    <% !@new && item.id == @changeset.data.id -> %>
                      <.edit_form f={f} account_id={@account_id} cancel={true} user_id={@modal.user.id} />
                    <% true -> %>
                      <td><%= item.name %></td>
                      <td><%= item.description %></td>
                      <td><%= if !item.locked do %><.toggle_active active={item.active} item_id={item.id} /><% end %></td>
                      <td><%= if !item.locked do %><.bnw_button_edit   phx-value-id={item.id} /><% end %></td>
                      <td><%= if !item.locked do %><.bnw_button_delete phx-value-id={item.id} /><% end %></td>
                  <% end %>
                </tr>
              <% end %>
            </.bnw_table>
          </.form>
        </.bnw_modal_body>
        <.bnw_modal_footer><.bnw_button_done /></.bnw_modal_footer>
      </.bnw_modal>
    </div>
    """
  end

  attr :f,          :any, required: true
  attr :account_id, :integer
  attr :user_id,    :integer
  attr :cancel,     :boolean, default: false
  def edit_form(assigns) do
    ~H"""
      <.bnw_input_hidden f={@f} field={:account_id} value={@account_id} />
      <.bnw_input_hidden f={@f} field={:user_id}    value={@user_id} />
      <td><.bnw_input_naked f={@f} field={:name}        display_name="Name" /></td>
      <td><.bnw_input_naked f={@f} field={:description} display_name="Description" /></td>
      <td><.bnw_input_naked f={@f} field={:active}      display_name="" type="checkbox"/></td>
      <td><%= if @cancel do %><.bnw_button_cancel phx_click="cancel_edit" /><% end %></td>
      <td><.bnw_button_submit /></td>
    """
  end

  attr :active,  :boolean, default: false
  attr :item_id, :integer
  def toggle_active(assigns) when assigns.active, do: ~H"<.bnw_button_icon bnw_icon='check' phx-value-id={@item_id} phx_click='deactivate'/>"
  def toggle_active(assigns), do:                     ~H"<.bnw_button_icon bnw_icon='ban'   phx-value-id={@item_id} phx_click='activate'/>"

  defp save(socket) do
    %{changeset: changeset} = socket.assigns
    cond do
      changeset.valid? ->
        changeset.data |> @module.create_or_update(changeset.changes)
        |> case do
          {:ok, _} -> socket |> assign(:changeset, @module.new_changeset()) |> assign(:new, true)
          {:error, changeset} -> socket |> assign(:changeset, changeset)
        end
      true -> socket
    end
  end

  defp cancel(socket) do
    %{parent: parent} = socket.assigns
    send(parent, :cancel)
    socket
  end

  defp fetch_items(socket) do
    %{
      page:       page,
      per_page:   per_page,
      items:      items,
      account_id:  account_id,
    } = socket.assigns

    socket |> assign(:items, items ++ @module.list(
      %{
        page:       page, 
        per_page:   per_page,
        account_id: account_id,
        preload:    [:account]
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
    end

    socket 
    |> assign(:modal,            modal)
    |> assign(:parent,           parent)
    |> assign(:account_id,       modal.account.id)
    |> assign(:page,             0)
    |> assign(:per_page,         10)
    |> assign(:items,            [])
    |> assign(:accounts,         [])
    |> assign(:changeset,        @module.new_changeset())
    |> assign(:new,              true)
    |> fetch_items()
    |> res(:ok)
  end

  @impl true
  def handle_info({[:account_sub, :created], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, [item |> Repo.preload([:account]) | items]) |> res()
  end
  @impl true
  def handle_info({[:account_sub, :updated], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item |> Repo.preload([:account]), else: &1))) |> res()
  end
  @impl true
  def handle_info({[:account_sub, :deleted], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.reject(items, &(&1.id == item.id))) |> res()
  end

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{changeset: changeset} = socket.assigns

    changeset =
      changeset.data
      |> @module.change(params |> Map.get(@key, %{}))
      |> Map.put(:action, :insert)

    socket
    |> assign(:changeset, changeset)
    |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{changeset: changeset} = socket.assigns

    changeset =
      changeset.data
      |> @module.change(params |> Map.get(@key, %{}))
      |> Map.put(:action, :insert)

    socket
    |> assign(:changeset, changeset)
    |> save()
    |> res()
  end

  @impl true 
  def handle_event("edit", %{"id" => id}, socket) do
    changeset = id |> String.to_integer() |> @module.get() |> @module.change()
    socket |> assign(:changeset, changeset) |> assign(:new, false) |> res()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id |> String.to_integer() |> @module.delete()
    socket |> res()
  end

  @impl true
  def handle_event("expand", %{"id" => id}, socket) do
    %{expanded: expanded} = socket.assigns
    id = String.to_integer(id)

    cond do
      id == expanded -> socket |> assign(:expanded, 0) |> assign(:changeset, @module.new_changeset) |> assign(:new, true) |> res()
      true -> socket |> assign(:expanded, id) |> assign(:changeset, id |> @module.get() |> @module.change()) |> assign(:new, false) |> res()
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket), do: socket |> assign(:changeset, @module.new_changeset) |> assign(:new, true) |> assign(:expanded, 0) |> res()

  @impl true
  def handle_event("cancel", _, socket), do: cancel(socket) |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_items()
    |> res()
  end

  @impl true
  def handle_event("deactivate", %{"id" => id}, socket) do
    id |> String.to_integer() |> @module.deactivate()
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    id |> String.to_integer() |> @module.activate()
    socket |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end



