defmodule BnwPortalWeb.Budget.Companies.Modals.ChangeDepartmentAccounts do
  use BnwPortalWeb, :live_view

  @module  Budget.CompanyDepartmentAccounts
  @key     "department_accounts"
  @section "departments"

  alias Budget.{
    Admins,
    CompanyAccounts,
    UserRoles,
    Roles,
    CompanyPermissions,
  }

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="department_accounts_modal">
          <.bnw_modal_header><%= @modal.opts.company_name %> - <%= @modal.opts.department_name %> - Depatment Accounts</.bnw_modal_header>
          <.bnw_modal_body>
            <.bnw_table height="60vh" id="department_accounts_table">
              <:header>
                <th class="p-2">Number</th>
                <th class="p-2">Name</th>
                <th class="p-2">Active</th>
              </:header>

              <%= for item <- @items do %>
                <tr id={"item_#{item.id}"}>
                  <td><%= item.account_number %></td>
                  <td><%= item.name %></td>
                  <td><.bnw_button_toggle_active edit={@edit} active={Enum.any?(@department_accounts, &(&1.account_id == item.id))} phx-value-id={item.id} /></td>
                </tr>
              <% end %>
            </.bnw_table>
          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_done id="a_different_done"/></.bnw_modal_footer>
        </.bnw_modal>
      <% end %>
    </div>
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

  defp fetch_department_accounts(socket) do
    %{
      department_accounts: department_accounts,
      department_id:       department_id,
    } = socket.assigns

    socket |> assign(:department_accounts, department_accounts ++ @module.list( %{ department_id: department_id, }))

  end
  defp fetch_items(socket) do
    %{
      page:       page,
      per_page:   per_page,
      items:      items,
      company_id: company_id,
    } = socket.assigns

    socket |> assign(:items, items ++ CompanyAccounts.list(
      %{
        page:       page, 
        per_page:   per_page,
        company_id: company_id,
        active:     true,
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
      Admins.subscribe()
      CompanyAccounts.subscribe()
      UserRoles.subscribe()
      Roles.subscribe()
      CompanyPermissions.subscribe()
    end

    socket 
    |> assign(:modal,               modal)
    |> assign(:parent,              parent)
    |> assign(:department_id,       modal.opts.department_id)
    |> assign(:company_id,          modal.opts.company_id)
    |> assign(:page,                0)
    |> assign(:per_page,            30)
    |> assign(:items,               [])
    |> assign(:department_accounts, [])
    |> assign(:new,                 true)
    |> assign(:edit,             false)
    |> assign(:view,             false)
    |> fetch_items()
    |> fetch_department_accounts()
    |> fetch_user_permissions()
    |> res(:ok)
  end

  #accounts
  @impl true
  def handle_info({[:account, :created], item}, socket) do
    %{items: items} = socket.assigns
    cond do
      item.active -> socket |> assign(:items, [item | items] |> Enum.uniq_by(&(&1.id)))
      true -> socket
    end |> res()
  end
  @impl true
  def handle_info({[:account, :updated], item}, socket) do
    %{items: items} = socket.assigns
    cond do
      item.active  && Enum.any?(items,  &(&1.id == item.id)) -> socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item, else: &1)))
      item.active  && !Enum.any?(items, &(&1.id == item.id)) -> socket |> assign(:items, [item | items])
      !item.active && Enum.any?(items,  &(&1.id == item.id)) -> socket |> assign(:items, Enum.reject(items, &(&1.id == item.id)))
      true -> socket
    end |> res()
    #socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:account, :deleted], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.reject(items, &(&1.id == item.id))) |> res()
  end

  #department_accounts
  @impl true
  def handle_info({[:department_account, :created], item}, socket) do
    %{department_accounts: department_accounts} = socket.assigns
    cond do
      item.department_id == socket.assigns.department_id ->
        socket |> assign(:department_accounts, [item | department_accounts]) |> res()
      true -> socket |> res()
    end
  end
  @impl true
  def handle_info({[:department_account, :deleted], item}, socket) do
    %{department_accounts: department_accounts} = socket.assigns
    socket |> assign(:department_accounts, Enum.reject(department_accounts, &(&1.id == item.id))) |> res()
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
    %{department_accounts: department_accounts} = socket.assigns
    id = id |> String.to_integer()
    department_accounts
    |> Enum.find(&(&1.account_id == id))
    |> Map.get(:id)
    |> @module.delete()
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    %{department_id: department_id} = socket.assigns
    @module.new()
    |> @module.create_or_update(
    %{
      department_id: department_id,
      account_id:    id,
    })
    socket |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end


