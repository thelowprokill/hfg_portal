defmodule HfgPortalWeb.TaskAutomationController.Manage.Roles.Modals.ChangeRoleJobs do
  use HfgPortalWeb, :live_view

  alias TaskAutomationController.{
    Jobs,
  }

  @module  TaskAutomationController.RoleJobs
  @key     "schedule"
  #@section "schedules"
  @preload []

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="role_users_modal" width="w-2/3">
        <.bnw_modal_header><%= @modal.opts.role.name %> - Roles</.bnw_modal_header>
        <.bnw_modal_body>
          <.form :let={f}
              for={@search_map}
              as={:search}
              phx-change="search"
              phx-submit="search">
            <.bnw_table_header_filter f={f} search_stack={@search_stack} sort_stack={@sort_stack} field={:username}>User Name</.bnw_table_header_filter>
          </.form>

          <div class="grid grid-cols-2">
            <div>
              <div class="p-2 text-xl">Active Roles</div>

              <%= for item <- @users |> Enum.filter(fn x -> Enum.any?(@items, &(&1.job_id == x.id)) end) do %>
                <.card item={item} active={true} />
              <% end %>
            </div>
            <div>
              <div class="p-2 text-xl">Inactive Roles</div>

              <%= for item <- @users |> Enum.filter(fn x -> !Enum.any?(@items, &(&1.job_id == x.id)) end) do %>
                <.card item={item} active={false} />
              <% end %>
            </div>

          </div>
        </.bnw_modal_body>
        <.bnw_modal_footer><.bnw_button_done /></.bnw_modal_footer>
      </.bnw_modal>
    </div>
    """
  end

  attr :item,   :map, required: true
  attr :active, :boolean, default: false
  def card(assigns) do
    ~H"""
      <div class="cursor-pointer px-4 py-2" 
        phx-click={if @active, do: "deactivate", else: "activate"} 
        phx-value-id={@item.id}
      >
        <%= @item.name %>
      </div>
    """
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
      role_id:    role_id,
    } = socket.assigns

    socket |> assign(:items, @module.list_user_roles(%{preload: @preload, role_id: role_id}))
  end

  defp fetch_users(socket) do
    socket |> assign(:users, Jobs.list() |> Enum.uniq_by(&(&1.id)))
  end

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
      Jobs.subscribe()
    end

    socket
    |> assign(:modal,          modal)
    |> assign(:parent,         parent)
    |> assign(:role_id,        modal.opts.role.id)
    |> assign(:page,           0)
    |> assign(:per_page,       30)
    |> assign(:items,          [])
    |> assign(:changeset,      @module.new_changeset())
    |> assign(:new,            true)
    |> assign(:search_map,     %{}) # search map is for the search form
    |> assign(:search_stack,   [])  # search stack is the data for all the search fields
    |> assign(:sort_stack,     [])  # sort stack is the data for all the sort fields
    |> assign(:session,        %{}) # session is kept so that the session can be updated
    |> fetch_items()
    |> fetch_users()
    |> res(:ok)
  end

  @impl true
  def handle_info({[:role, :created], item}, socket) do
    %{roles: roles} = socket.assigns
    socket |> assign(:roles, [item | roles] |> Enum.uniq_by(&(&1.id))) |> res()
  end
  @impl true
  def handle_info({[:role, :updated], item}, socket) do
    %{roles: roles} = socket.assigns
    socket |> assign(:roles, Enum.map(roles, &(if &1.id == item.id, do: item, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:role, :deleted], item}, socket) do
    %{roles: roles} = socket.assigns
    socket |> assign(:roles, Enum.reject(roles, &(&1.id == item.id))) |> res()
  end

  @impl true
  def handle_info({[_, _, :created], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, [item |> @module.preload(%{preload: @preload}) | items] |> Enum.uniq_by(&(&1.id))) |> res()
  end
  @impl true
  def handle_info({[_, _, :updated], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item |> @module.preload(%{preload: @preload}), else: &1))) |> res()
  end
  @impl true
  def handle_info({[_, _, :deleted], item}, socket) do
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
    %{items: items} = socket.assigns
    items |> Enum.find(&(&1.job_id == id |> String.to_integer())) |> @module.delete()
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    %{role_id: role_id, modal: %{user: %{id: changed_by_id}}} = socket.assigns

    @module.new()
    |> @module.create_or_update(
      %{
        job_id:  id |> String.to_integer(),
        role_id: role_id,
        active:  true,
        created_by_id: changed_by_id,
        updated_by_id: changed_by_id,
      }
    )
    socket |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
