defmodule BnwPortalWeb.Budget.Companies.Modals.ChangeCompanyPermissions do
  use BnwPortalWeb, :live_view

  alias Budget.{
    Admins,
    UserRoles,
    Roles,
    CompanyPermissions,
  }

  @module  Budget.CompanyPermissions
  @key     "permission_companies"
  @section "roles"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="permission_companies_modal">
          <.bnw_modal_header><%= @modal.opts.company_name %> - <%= @modal.opts.role_name %> - Company Permissions</.bnw_modal_header>
          <.bnw_modal_body>
            <.bnw_table height="60vh" id="permission_company_table" load_more={false}>
              <:header>
                <th class="p-2 w-1/3">Page</th>
                <%= for %{label: label} <- @perms do %>
                  <th class="p-2"><%= label %></th>
                <% end %>
              </:header>

              <%= for %{section: section, label: label} <- @sections do %>
                <% perm = Enum.find(@permissions, &(&1.section == section)) %>
                <tr>
                  <td><%= label %></td>
                  <%= for {%{permission: permission}, i} <- @perms |> Enum.with_index() do %>
                    <td>
                      <% active = perm && perm.permission in (@perms |> Enum.take((length(@perms) - i) * -1) |> Enum.map(&(&1.permission))) %>
                      <.bnw_button_toggle_active edit={@edit} phx-value-section={section} phx-value-permission={permission} active={active} />
                    </td>
                  <% end %>
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

  defp fetch_items(socket) do
    %{
      permissions: permissions,
      role_id:     role_id,
    } = socket.assigns

    socket |> assign(:permissions, permissions ++ @module.list(
      %{
        role_id:  role_id
      }
    ))
  end

  defp fetch_sections(socket),    do: socket |> assign(:sections, @module.list_sections())
  defp fetch_permissions(socket), do: socket |> assign(:perms,    @module.list_permissions())

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
    |> assign(:modal,         modal)
    |> assign(:parent,        parent)
    |> assign(:role_id,       modal.opts.role_id)
    |> assign(:company_id,    modal.opts.company_id)
    |> assign(:items,         [])
    |> assign(:permissions,   [])
    |> assign(:edit,          false)
    |> assign(:view,          false)
    |> fetch_sections()
    |> fetch_permissions()
    |> fetch_items()
    |> fetch_user_permissions()
    |> res(:ok)
  end

  #permissions
  @impl true
  def handle_info({[:budget, :company_permission, :created], perm}, socket) do
    %{permissions: permissions, role_id: role_id} = socket.assigns
    cond do
      perm.role_id == role_id -> socket |> assign(:permissions, [perm | permissions] |> Enum.uniq_by(&(&1.id)))
      true -> socket
    end
    |> fetch_user_permissions()
    |> res()
  end
  @impl true
  def handle_info({[:budget, :company_permission, :updated], perm}, socket) do
    %{permissions: permissions} = socket.assigns
    socket |> assign(:permissions, Enum.map(permissions, &(if &1.id == perm.id, do: perm, else: &1))) 
    |> fetch_user_permissions() |> res()
  end
  @impl true
  def handle_info({[:budget, :company_permission, :deleted], perm}, socket) do
    %{permissions: permissions} = socket.assigns
    socket |> assign(:permissions, Enum.reject(permissions, &(&1.id == perm.id)))
    |> fetch_user_permissions() |> res()
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
  def handle_event("expand_department", %{"id" => id}, socket) do
    %{expanded_department: expanded_department} = socket.assigns
    cond do
      expanded_department == id |> String.to_integer() -> socket |> assign(:expanded_department, 0)
      true -> socket |> assign(:expanded_department, id |> String.to_integer())
    end |> res()
  end

  @impl true
  def handle_event("deactivate", %{"permission" => perm, "section" => section}, socket) do
    %{
      company_id:  company_id,
      modal:       %{opts: %{user_id: user_id}},
      permissions: permissions,
      perms:       perms,
      role_id:     role_id,
    } = socket.assigns

    new_perm = 
      perms
      |> Enum.with_index()
      |> Enum.find(fn {p, _} -> p.permission == perm end)
      |> elem(1)
      |> case do
        0 -> nil
        i -> Enum.at(perms, i - 1) |> Map.get(:permission)
      end

    cond do
      new_perm == nil -> Enum.find(permissions, &(&1.section == section)) |> @module.delete()
      true ->
        Enum.find(permissions, &(&1.section == section))
        |> @module.create_or_update(
          %{
            company_id:    company_id,
            role_id:       role_id,
            section:       section,
            permission:    new_perm,
            updated_by_id: user_id
          })
    end 
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"permission" => perm, "section" => section}, socket) do
    %{
      company_id:  company_id,
      modal:       %{opts: %{user_id: user_id}},
      permissions: permissions,
      role_id:     role_id,
    } = socket.assigns

    Enum.find(permissions, %{@module.new() | created_by_id: user_id}, &(&1.section == section))
    |> @module.create_or_update(
      %{
        company_id:    company_id,
        role_id:       role_id,
        section:       section,
        permission:    perm,
        updated_by_id: user_id
      })
    socket |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
