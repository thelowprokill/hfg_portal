defmodule BnwPortalWeb.Budget.Companies.Modals.ChangeReportingInputs do
  use BnwPortalWeb, :live_view

  alias Budget.{
    Admins,
    UserRoles,
    Roles,
    CompanyPermissions,
  }

  @module  Budget.CompanyReportingInputs
  @key     "reporting_input"
  @section "reporting_inputs"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="reporting_inputs_modal">
          <.bnw_modal_header><%= @modal.opts.company_name %> - Reporting Inputs</.bnw_modal_header>
          <.bnw_modal_body>
            <.form :let={f}
              for={@changeset}
              phx-change="validate"
              phx-submit="save">
              <.bnw_table height="60vh" id="reporting_inputs_table">
                <:header>
                  <th class="p-2">Name</th>
                  <th class="p-2">Active</th>
                  <%= if @new do %>
                    <th class="p-2"></th>
                    <th class="p-2"></th>
                  <% end %>
                </:header>

                <tr id="new_item"><%= if @new && @edit do %><.edit_form f={f} company_id={@company_id} /><% end %></tr>

                <%= for item <- @items do %>
                  <tr id={"item_#{item.id}"}>
                    <%= cond do %>
                      <% !@new && @edit && item.id == @changeset.data.id -> %>
                        <.edit_form f={f} company_id={@company_id} cancel={true} />
                      <% true -> %>
                        <td><%= item.name %></td>
                        <td><.bnw_button_toggle_active edit={@edit} active={item.active} phx-value-id={item.id} /></td>
                        <%= if @edit do %>
                          <td><.bnw_button_edit   phx-value-id={item.id} /></td>
                          <td><.bnw_button_delete phx-value-id={item.id} /></td>
                        <% end %>
                    <% end %>
                  </tr>
                <% end %>
              </.bnw_table>
            </.form>
          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_done /></.bnw_modal_footer>
        </.bnw_modal>
      <% end %>
    </div>
    """
  end

  attr :f,          :any, required: true
  attr :company_id, :integer
  attr :cancel,     :boolean, default: false
  def edit_form(assigns) do
    ~H"""
      <.bnw_input_hidden f={@f} field={:company_id} value={@company_id} />
      <td><.bnw_input_naked f={@f} field={:name}   display_name="Name"/></td>
      <td><.bnw_input_naked f={@f} field={:active} display_name="" type="checkbox"/></td>
      <td><%= if @cancel do %><.bnw_button_cancel phx_click="cancel_edit" /><% end %></td>
      <td><.bnw_button_submit /></td>
    """
  end

  defp fetch_user_permissions(socket) do
    %{
      modal:      %{user: user},
      company_id: company_id
    } = socket.assigns
    cond do 
      (user.dev_admin && user.admin_mode) || Admins.is_admin(user.id) -> socket |> assign(:edit, true) |> assign(:view, true)
      true ->
        %{company_permissions: company_permissions} = UserRoles.fetch_user_permissions(user.id)

        edit = Enum.any?(company_permissions, &(&1.company_id == company_id && &1.section == @section && &1.permission in ["admin", "edit"]))
        view = Enum.any?(company_permissions, &(&1.company_id == company_id && &1.section == @section))
        socket |> assign(:edit, edit) |> assign(:view, view)
    end
  end

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
      company_id: company_id,
    } = socket.assigns

    socket |> assign(:items, items ++ @module.list(
      %{
        page:       page,
        per_page:   per_page,
        company_id: company_id,
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
      Admins.subscribe()
      UserRoles.subscribe()
      Roles.subscribe()
      CompanyPermissions.subscribe()
    end

    socket
    |> assign(:modal,            modal)
    |> assign(:parent,           parent)
    |> assign(:company_id,       modal.opts.company_id)
    |> assign(:page,             0)
    |> assign(:per_page,         30)
    |> assign(:items,            [])
    |> assign(:changeset,        @module.new_changeset())
    |> assign(:new,              true)
    |> assign(:edit,             false)
    |> assign(:view,             false)
    |> fetch_items()
    |> fetch_user_permissions()
    |> res(:ok)
  end

  @impl true
  def handle_info({[_, :created], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, [item | items] |> Enum.uniq_by(&(&1.id))) |> res()
  end
  @impl true
  def handle_info({[_, :updated], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item, else: &1))) |> res()
  end
  @impl true
  def handle_info({[_, :deleted], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.reject(items, &(&1.id == item.id))) |> res()
  end

  @impl true
  def handle_info({[:budget, _, _], _}, socket) do
    socket |> fetch_user_permissions() |> res()
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
  def handle_event("cancel_edit", _, socket), do: socket |> assign(:changeset, @module.new_changeset) |> assign(:new, true) |> res()

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
