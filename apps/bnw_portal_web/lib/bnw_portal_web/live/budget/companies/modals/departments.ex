defmodule BnwPortalWeb.Budget.Companies.Modals.ChangeDepartments do
  use BnwPortalWeb, :live_view

  alias Budget.{
    Admins,
    CompanyVariableInputs,
    UserRoles,
    Roles,
    CompanyPermissions,
  }

  @module  Budget.CompanyDepartments
  @key     "department"
  @section "departments"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="department_modal" width="w-1/2">
          <.bnw_modal_header><%= @modal.opts.company_name %> - Departments</.bnw_modal_header>
          <.bnw_modal_body>
            <.form :let={f}
              for={@changeset}
              phx-change="validate"
              phx-submit="save">
              <.bnw_table height="60vh" id="department_table">
                <:header>
                  <th class="p-2">Name</th>
                  <th class="p-2">Number</th>
                  <th class="p-2">External Code</th>
                  <th class="p-2 w-1/5">Variable Input</th>
                  <th class="p-2">Active</th>
                  <th class="p-2">Department Accounts</th>
                  <%= if @edit do %>
                    <th class="p-2"></th>
                    <th class="p-2"></th>
                  <% end %>
                </:header>

                <tr id="new_item"><%= if @new && @edit do %><.edit_form f={f} company_id={@company_id} variable_inputs={@variable_inputs} /><% end %></tr>

                <%= for item <- @items do %>
                  <tr id={"item_#{item.id}"}>
                    <%= cond do %>
                      <% !@new && @edit && item.id == @changeset.data.id -> %>
                        <.edit_form f={f} company_id={@company_id} cancel={true} variable_inputs={@variable_inputs} />
                      <% true -> %>
                        <td><%= item.name %></td>
                        <td><%= item.department_number %></td>
                        <td><%= item.external_code %></td>
                        <td><%= item.variable_input_name %></td>
                        <td><.bnw_button_toggle_active edit={@edit} active={item.active} phx-value-id={item.id} /></td>
                        <td><.bnw_button_icon   phx-value-id={item.id} phx-value-company_id={@company_id} phx_click="edit_accounts" bnw_icon="settings" /></td>
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

  attr :f,               :any, required: true
  attr :company_id,      :integer
  attr :cancel,          :boolean, default: false
  attr :variable_inputs, :list
  def edit_form(assigns) do
    ~H"""
      <.bnw_input_hidden f={@f} field={:company_id} value={@company_id} />
      <% id = @f |> Map.get(:source) |> Map.get(:changes) |> Map.get(:variable_input_id_in, -1) %>
      <% name = Enum.find(@variable_inputs, fn x -> Keyword.get(x, :value) == id end) |> Keyword.get(:key) %>
      <.bnw_input_hidden f={@f} field={:variable_input_name} value={name} />
      <td><.bnw_input_naked f={@f} field={:name}                 display_name="Name"/></td>
      <td><.bnw_input_naked f={@f} field={:department_number}    display_name="Number"/></td>
      <td><.bnw_input_naked f={@f} field={:external_code}        display_name="External Code"/></td>
      <td><.bnw_input_naked f={@f} field={:variable_input_id_in} display_name="Variable Input" type="select" list={@variable_inputs}/></td>
      <td><.bnw_input_naked f={@f} field={:active}               display_name="" type="checkbox"/></td>
      <td></td>
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

  defp department_accounts(socket, ids) do
    %{parent: parent} = socket.assigns
    send(parent, {:department_accounts, ids})
    socket
  end

  defp fetch_variable_inputs(socket) do
    socket |> assign(:variable_inputs, 
      (Budget.CompanyPermVariableInputs.list() ++ CompanyVariableInputs.list())
      |> Enum.map(&([key: &1.name, value: &1.id]))
    )
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
      CompanyVariableInputs.subscribe()
      UserRoles.subscribe()
      Roles.subscribe()
      CompanyPermissions.subscribe()
    end

    socket 
    |> assign(:modal,               modal)
    |> assign(:parent,              parent)
    |> assign(:company_id,          modal.opts.company_id)
    |> assign(:page,                0)
    |> assign(:per_page,            30)
    |> assign(:items,               [])
    |> assign(:variable_inputs,     [])
    |> assign(:changeset,           @module.new_changeset())
    |> assign(:new,                 true)
    |> assign(:edit,             false)
    |> assign(:view,             false)
    |> assign(:department_accounts, nil)
    |> fetch_items()
    |> fetch_variable_inputs()
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
  def handle_event("edit_accounts", %{"id" => id, "company_id" => c_id}, socket) do
    %{items: items} = socket.assigns
    socket |> department_accounts({id |> String.to_integer, c_id |> String.to_integer, Enum.find(items, &(&1.id == String.to_integer(id))).name}) |> res()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id |> String.to_integer() |> @module.delete()
    socket |> res()
  end

  @impl true
  def handle_event("cancel_edit", _, socket), do: socket |> assign(:changeset, @module.new_changeset) |> assign(:new, true) |> res()

  @impl true
  def handle_event("cancel", _, socket) do
    cancel(socket) |> res()
  end

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

