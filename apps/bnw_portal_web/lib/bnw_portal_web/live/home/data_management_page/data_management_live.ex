defmodule BnwPortalWeb.Home.DataManagement.DataManagementLive do
  use BnwPortalWeb, :live_view
  use Phoenix.HTML

  alias BnwPortal.{
    Accounts,
    DataManagementItems,
    DataManagementGroups,
  }

  alias BnwPortalWeb.Home.DataManagement.{
    ChangeItem,
    ChangeGroup
  }

  @preload [items: DataManagementGroups.item_query()]

  defp fetch_groups(socket) do
    groups = DataManagementGroups.list(%{preload: @preload})

    socket
    |> assign(:groups, groups)
  end

  defp set_modal(socket, modal \\ nil, id \\ nil)
  defp set_modal(socket, :new_group, _) do
    %{
      groups:      groups,
      modal_stack: modal_stack
    } = socket.assigns

    order =
      groups
      |> Enum.map(&(&1.id))
      |> Enum.max(&>=/2, fn -> 0 end)
      |> fn x -> x + 1 end.()

    changeset = DataManagementGroups.new_changeset()

    socket
    |> assign(:modal_stack, [%Modal{
      modal:     :new_group,
      id:        :new,
      module:    ChangeGroup,
      changeset: changeset,
      opts:      %{order: order}
    } | modal_stack])
  end
  defp set_modal(socket, :edit_group, id) do
    %{
      groups:      groups,
      modal_stack: modal_stack
    } = socket.assigns

    changeset =
      groups
      |> Enum.find(&(&1.id == id))
      |> DataManagementGroups.change()

    socket
    |> assign(:modal_stack, [%Modal{
      modal:     :edit_group,
      id:        id,
      module:    ChangeGroup,
      changeset: changeset,
      opts:      %{order: Map.get(changeset.data, :order)}
    } | modal_stack])
  end

  defp set_modal(socket, :new_item, group_id) do
    %{modal_stack: modal_stack} = socket.assigns
    order =
      DataManagementItems.list(%{group_id: group_id})
      |> Enum.map(&(&1.order))
      |> Enum.max(&>=/2, fn -> 0 end)
      |> fn x -> x + 1 end.()

    changeset = DataManagementItems.new_changeset()

    socket
    |> assign(:modal_stack, [%Modal{
      modal:     :new_item,
      id:        :new,
      module:    ChangeItem,
      changeset: changeset,
      opts:      %{order: order, group_id: group_id}
    } | modal_stack])
  end

  defp set_modal(socket, :edit_item, id) do
    %{
      groups:      groups,
      modal_stack: modal_stack
    } = socket.assigns

    changeset =
      groups
      |> Enum.find(fn x -> Enum.any?(x.items, &(&1.id == id)) end)
      |> fn x -> x.items end.()
      |> Enum.find(&(&1.id == id))
      |> DataManagementItems.change()

    socket
    |> assign(:modal_stack, [%Modal{
      modal:     :edit_item,
      id:        id,
      module:    ChangeItem,
      changeset: changeset,
      opts:      %{order: Map.get(changeset.data, :order), group_id: Map.get(changeset.data, :group_id)}
    } | modal_stack])
  end

  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  defp set_edit_mode(%{assigns: %{current_user: %{portal_admin: true}}} = socket, true), do: socket |> assign(:edit_mode, true)
  defp set_edit_mode(socket, _), do: socket |> assign(:edit_mode, false) |> set_modal()

  attr :item, :map,     required: true
  attr :show, :boolean, default:  false
  defp show_qr_code(assigns) when assigns.show, do: ~H"""
    <div class="w-full grid grid-cols-4">
      <a class="col-span-2" target={if @item.new_tab, do: "_blank", else: "_parent"} href={@item.link}>
        <span class="text-primary-main hover:text-primary-hover"><%= @item.name %></span>
      </a>
      <.bnw_button phx_click="hide_qr_code" phx-value-id={@item.id}>Hide QR Code</.bnw_button>
      <span class="content-end"><%= raw(@item.link |> QRCodeEx.encode() |> QRCodeEx.svg(width: 100)) %></span>
    </div>
  """
  defp show_qr_code(assigns), do: ~H"""
    <div class="w-full grid grid-cols-4">
      <a class="col-span-2" target={if @item.new_tab, do: "_blank", else: "_parent"} href={@item.link}>
        <span class="text-primary-main hover:text-primary-hover"><%= @item.name %></span>
      </a>
      <.bnw_button phx_click="show_qr_code" phx-value-id={@item.id}>Show QR Code</.bnw_button>
    </div>
  """

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
      DataManagementGroups.subscribe()
      DataManagementItems.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "#{(System.get_env("LOCATION") || "bnw") |> String.upcase} Portal", "Home")
    |> assign(:edit_mode,     false)
    |> assign(:modal_stack,   [])
    |> assign(:show_qr_codes, [])
    |> fetch_groups()
    |> set_modal()
    |> res(:ok)
  end

  @impl true
  def handle_info({[:data_management_group, :created], group}, socket) do
    %{groups: groups} = socket.assigns
    socket |> assign(:groups, [group |> DataManagementGroups.preload(%{preload: @preload})| groups] |> Enum.sort_by(&(&1.order))) |> res()
  end
  @impl true
  def handle_info({[:data_management_group, :updated], group}, socket) do
    %{groups: groups} = socket.assigns
    socket |> assign(:groups, Enum.map(groups, &(if &1.id == group.id, do: group |> DataManagementGroups.preload(%{preload: @preload}), else: &1)) |> Enum.sort_by(&(&1.order))) |> res()
  end
  @impl true
  def handle_info({[:data_management_group, :deleted], group}, socket) do
    %{groups: groups} = socket.assigns

    socket
    |> assign(:groups, Enum.reject(groups, &(&1.id == group.id)))
    |> res()
  end

  @impl true
  def handle_info({[:data_management_item, :created], item}, socket) do
    %{groups: groups} = socket.assigns

    socket |> assign(:groups, Enum.map(groups, fn x ->
      cond do
        x.id == item.group_id -> Map.put(x, :items, x.items ++ [item])
        true -> x
      end
    end)) |> res()
  end
  @impl true
  def handle_info({[:data_management_item, :updated], item}, socket) do
    %{groups: groups} = socket.assigns

    socket |> assign(:groups, Enum.map(groups, fn x ->
      cond do
        x.id == item.group_id ->
          items = Enum.map(x.items, fn y ->
            cond do
              y.id == item.id -> item
              true -> y
            end
          end)
          Map.put(x, :items, Enum.sort_by(items, &(&1.order)))
        true -> x
      end
    end)) |> res()
  end
  @impl true
  def handle_info({[:data_management_item, :deleted], item}, socket) do
    %{groups: groups} = socket.assigns

    socket
    |> assign(:groups, Enum.map(groups, fn x -> Map.put(x, :items, Enum.reject(x.items, &(&1.id == item.id))) end))
    |> res()
  end

  @impl true
  def handle_info({[:user, :updated], user}, socket) do
    %{current_user: current_user, edit_mode: edit_mode} = socket.assigns

    cond do
      current_user.id == user.id -> socket |> assign(:current_user, user)
      true -> socket
    end
    |> set_edit_mode(edit_mode)
    |> res()
  end

  @impl true
  def handle_info({:cancel}, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__ |> to_string())
    {:noreply, socket}
  end

  # groups
  @impl true
  def handle_event("new_group", _, %{assigns: %{current_user: %{portal_admin: true}}} = socket) do
    socket
    |> set_modal(:new_group)
    |> res()
  end

  @impl true
  def handle_event("edit_group", %{"id" => group_id}, %{assigns: %{current_user: %{portal_admin: true}}} = socket) do
    socket
    |> set_modal(:edit_group, String.to_integer(group_id))
    |> res()
  end

  @impl true
  def handle_event("delete_group", %{"id" => group_id}, %{assigns: %{current_user: %{portal_admin: true}}} = socket) do
    DataManagementGroups.delete(String.to_integer(group_id))
    res(socket)
  end

  @impl true
  def handle_event("move_up_group", %{"id" => id}, %{assigns: %{current_user: %{portal_admin: true}}} = socket) do
    DataManagementGroups.move_up(String.to_integer(id))
    res(socket)
  end

  # items
  @impl true
  def handle_event("new_item", %{"id" => group_id}, %{assigns: %{current_user: %{portal_admin: true}}} = socket) do
    socket
    |> set_modal(:new_item, String.to_integer(group_id))
    |> res()
  end

  @impl true
  def handle_event("edit_item", %{"id" => id}, %{assigns: %{current_user: %{portal_admin: true}}} = socket) do
    socket
    |> set_modal(:edit_item, String.to_integer(id))
    |> res()
  end

  @impl true
  def handle_event("move_up_item", %{"id" => id}, %{assigns: %{current_user: %{portal_admin: true}}} = socket) do
    DataManagementItems.move_up(String.to_integer(id))
    res(socket)
  end

  @impl true
  def handle_event("delete_item", %{"id" => id}, %{assigns: %{current_user: %{portal_admin: true}}} = socket) do
    DataManagementItems.delete(String.to_integer(id))
    res(socket)
  end

  @impl true
  def handle_event("toggle_edit_mode", _, %{assigns: %{edit_mode: edit_mode, current_user: %{portal_admin: true}}} = socket) do
    socket
    |> set_edit_mode(!edit_mode)
    |> res()
  end

  @impl true
  def handle_event("toggle_show_qr_codes", _, socket), do: socket |> assign(:show_qr_codes, !socket.assigns.show_qr_codes) |> res()

  @impl true
  def handle_event("show_qr_code", %{"id" => id}, socket) do
    socket |> assign(:show_qr_codes, [String.to_integer(id) | socket.assigns.show_qr_codes]) |> res()
  end
  @impl true
  def handle_event("hide_qr_code", %{"id" => id}, socket) do
    socket |> assign(:show_qr_codes, Enum.reject(socket.assigns.show_qr_codes, &(&1 == String.to_integer(id)))) |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__ |> to_string())
    {:noreply, socket}
  end
end
