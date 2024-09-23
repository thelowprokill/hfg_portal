defmodule BnwPortalWeb.Budget.Companies.Modals.ChangeUserRoles do
  use BnwPortalWeb, :live_view

  alias Budget.{
    Admins,
    UserRoles,
    Roles,
    CompanyPermissions,
  }

  @module  Budget.UserRoles
  @key     "user_roles"
  @section "user_roles"

  alias Budget.{
    Users,
    Roles,
  }

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="user_roles_modal" width="w-2/3">
          <.bnw_modal_header>
            <%= @modal.opts.company_name %> 
            <%= if @role_id, do: " - #{@role_name}" %>
            - User Roles
          </.bnw_modal_header>
          <.bnw_modal_body>
            <%= for item <- @items do %>
              <%= if @role_id do %>
                <div class="grid grid-cols-2">
                  <%= item.username %>
                  <.toggle_active  edit={@edit}
                    active={Enum.any?(@user_roles, &(&1.user_id == item.id && &1.role_id == @role_id))} 
                    user_id={item.id} 
                    role={Enum.find(@roles, &(&1.id == @role_id))}
                  />
                </div>
              <% else %>
                <.bnw_expand name={item.username} expanded={item.id in @expanded} click="expand" click_id={item.id}>
                  <div class="grid grid-cols-4">
                    <%= for role <- @roles do %>
                      <div>
                        <.toggle_active edit={@edit} active={Enum.any?(@user_roles, &(&1.user_id == item.id && &1.role_id == role.id))} user_id={item.id} role={role} />
                      </div>
                    <% end %>
                  </div>
                </.bnw_expand>
              <% end %>
            <% end %>
          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_done id="user_roles_done"/></.bnw_modal_footer>
        </.bnw_modal>
      <% end %>
    </div>
    """
  end

  attr :active,  :boolean, default: false
  attr :user_id, :integer, required: true
  attr :role,    :map,     required: true
  attr :edit,    :boolean, default: false
  def toggle_active(assigns) when not assigns.edit and assigns.active, do: ~H"<div class='flex mx-2'><.bnw_icon class='text-success-main' bnw_icon='check'/><%= @role.name %></div>"
  def toggle_active(assigns) when not assigns.edit, do: ~H"<div class='flex mx-2'><.bnw_icon class='text-danger-main' bnw_icon='ban'/><%= @role.name %></div>"
  def toggle_active(assigns) when assigns.active, do: ~H"""
    <.bnw_button 
      phx-value-user_id={@user_id} 
      phx-value-role_id={@role.id} 
      phx_click='deactivate'
    >
      <div class="flex">
        <.bnw_icon 
          class='mx-2 text-success-main hover:text-success-hover' 
          bnw_icon='check' 
          phx-value-ussr_id={@user_id} 
          phx-value-role_id={@role.id} 
          phx_click='deactivate'
        />
        <%= @role.name %>
      </div>
    </.bnw_button>
    """
  def toggle_active(assigns), do: ~H"""
    <.bnw_button 
      phx-value-user_id={@user_id} 
      phx-value-role_id={@role.id} 
      phx_click='activate'
    >
      <div class="flex">
        <.bnw_icon 
          class='text-danger-main hover:text-danger-hover' 
          bnw_icon='ban'   
          phx-value-ussr_id={@user_id} 
          phx-value-role_id={@role.id} 
        />
        <%= @role.name %>
      </div>
    </.bnw_button>
    """

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
      page:     page,
      per_page: per_page,
      items:    items,
    } = socket.assigns

    socket |> assign(:items, items ++ Users.list(
      %{
        page:     page,
        per_page: per_page,
      }
    ))
  end

  defp fetch_roles(socket) do
    %{
      company_id: company_id,
      role_id:    role_id,
    } = socket.assigns

    socket |> assign(:roles, Roles.list(%{
      company_id: company_id,
      role_id:    role_id,
    }))
  end

  defp fetch_user_roles(socket) do
    %{
      company_id: company_id,
    } = socket.assigns

    socket |> assign(:user_roles, @module.list(%{
      company_id: company_id
    }))
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
    |> assign(:modal,         modal)
    |> assign(:parent,        parent)
    |> assign(:company_id,    modal.opts.company_id)
    |> assign(:role_id,       Map.get(modal.opts, :role_id))
    |> assign(:role_name,     Map.get(modal.opts, :role_name))
    |> assign(:page,          0)
    |> assign(:per_page,      30)
    |> assign(:items,         [])
    |> assign(:roles,         [])
    |> assign(:user_roles,    [])
    |> assign(:expanded,      [])
    |> assign(:edit,          false)
    |> assign(:view,          false)
    |> fetch_items()
    |> fetch_roles()
    |> fetch_user_roles()
    |> fetch_user_permissions()
    |> res(:ok)
  end

  # user_roles
  @impl true
  def handle_info({[:budget, :user_role, :created], item}, socket) do
    %{user_roles: user_roles} = socket.assigns
    socket |> assign(:user_roles, [item | user_roles] |> Enum.uniq_by(&(&1.id)))
    |> res()
  end
  @impl true
  def handle_info({[:budget, :user_role, :updated], item}, socket) do
    %{user_roles: user_roles} = socket.assigns
    socket |> assign(:items, Enum.map(user_roles, &(if &1.id == item.id, do: item, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:budget, :user_role, :deleted], item}, socket) do
    %{user_roles: user_roles} = socket.assigns
    socket |> assign(:user_roles, Enum.reject(user_roles, &(&1.id == item.id)))
    |> res()
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
  def handle_event("deactivate", %{"role_id" => role_id, "user_id" => user_id}, socket) do
    %{user_roles: user_roles} = socket.assigns

    role_id = String.to_integer(role_id)
    user_id = String.to_integer(user_id)

    Enum.find(user_roles, &(&1.role_id == role_id && &1.user_id == user_id)) |> @module.delete()
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"role_id" => role_id, "user_id" => user_id}, socket) do
    %{
      modal:       %{opts: %{user_id: curr_user_id}},
      user_roles:  user_roles,
    } = socket.assigns

    role_id = String.to_integer(role_id)
    user_id = String.to_integer(user_id)

    Enum.find(user_roles, %{@module.new() | created_by_id: curr_user_id}, &(&1.user_id == user_id && &1.role_id == role_id))
    |> @module.create_or_update(
      %{
        role_id:       role_id,
        user_id:       user_id,
        updated_by_id: curr_user_id
      })
    socket |> res()
  end

  @impl true
  def handle_event("expand", %{"id" => id}, socket) do
    %{expanded: expanded} = socket.assigns
    id = String.to_integer(id)
    expanded = cond do
      id in expanded -> Enum.reject(expanded, &(&1 == id))
      true -> [id | expanded]
    end
    socket |> assign(:expanded, expanded) |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
