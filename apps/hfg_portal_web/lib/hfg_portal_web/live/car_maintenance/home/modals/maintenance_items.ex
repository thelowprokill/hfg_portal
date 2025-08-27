defmodule HfgPortalWeb.CarMaintenance.Home.Modals.ChangeMaintenanceItems do
  use HfgPortalWeb, :live_view

  @module  CarMaintenance.MaintenanceItems
  @key     "maintenance_item"
  @preload []

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="maintenance_items_modal" width="w-full">
          <.bnw_modal_header><%= @modal.opts.car_name %> - Maintenance Items</.bnw_modal_header>
          <.bnw_modal_body>
            <.form :let={f}
              for={@changeset}
              phx-change="validate"
              phx-submit="save">
              <.bnw_table height="60vh" id="timesheets_table">
                <:header>
                  <.bnw_th>Name</.bnw_th>
                  <.bnw_th>Interval Miles</.bnw_th>
                  <.bnw_th>Interval Months</.bnw_th>
                  <.bnw_th>Notes</.bnw_th>
                  <.bnw_th>Active</.bnw_th>
                  <.bnw_th></.bnw_th>
                </:header>

                <tr id="new_item">
                  <%= if @new && @edit do %>
                    <.edit_form 
                      f={f} 
                      car_id={@car_id} 
                      user_id={@user.id} 
                    />
                  <% end %>
                </tr>

                <%= for item <- @items do %>
                  <tr id={"item_#{item.id}"}>
                    <%= cond do %>
                      <% !@new && @edit && item.id == @changeset.data.id -> %>
                        <.edit_form 
                          f={f} 
                          car_id={@car_id} 
                          user_id={@user.id} 
                          cancel={true} 
                        />
                      <% true -> %>
                        <td class="px-2"><%= item.name %></td>
                        <td class="px-2"><%= item.interval_miles %></td>
                        <td class="px-2"><%= item.interval_months %></td>
                        <td class="px-2"><%= item.notes %></td>
                        <td class="px-2"><.toggle_active active={item.active} item_id={item.id} /></td>
                        <td class="px-2"><.bnw_button_edit   phx-value-id={item.id} /></td>
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

  attr :f,                :any, required: true
  attr :car_id,           :integer
  attr :user_id,          :integer
  attr :cancel,           :boolean, default: false
  def edit_form(assigns) do
    ~H"""
      <%= if @cancel do %>
        <.bnw_input_hidden f={@f} field={:created_by_id} value={@user_id} />
      <% end %>
      <.bnw_input_hidden f={@f} field={:car_id}        value={@car_id} />
      <.bnw_input_hidden f={@f} field={:updated_by_id} value={@user_id} />

      <td class="px-2"><.bnw_input_naked f={@f} type="text"     field={:name}            display_name="Name"/></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="number"   field={:interval_miles}  display_name="Interval Miles"/></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="number"   field={:interval_months} display_name="Interval Months"/></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="text"     field={:notes}           display_name="Notes"/></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="checkbox" field={:active}          display_name="Active"/></td>
      <td class="px-2"><%= if @cancel do %><.bnw_button_cancel phx_click="cancel_edit" /><% end %></td>
      <td class="px-2"><.bnw_button_submit /></td>
    """
  end

  attr :active,  :boolean, default: false
  attr :item_id, :integer
  def toggle_active(assigns) when assigns.active, do: ~H"""
    <.bnw_button_icon
      class='text-success-main hover:text-success-hover' 
      bnw_icon='check'
      phx-value-id={@item_id}
      phx_click='deactivate'
    />
    """
  def toggle_active(assigns), do: ~H"""
    <.bnw_button_icon
      class='text-danger-main hover:text-danger-hover' 
      bnw_icon='ban'
      phx-value-id={@item_id}
      phx_click='activate'
    />
    """

  defp save(socket) do
    %{changeset: changeset} = socket.assigns
    cond do
      changeset.valid? ->
        changeset.data |> @module.create_or_update(changeset.changes)
        |> case do
          {:ok, _} -> socket |> assign(:changeset, @module.new_changeset(%{entry_date: Date.utc_today()})) |> assign(:new, true)
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
      car_id:   car_id,
    } = socket.assigns

    socket |> assign(:items, items ++ @module.list(
      %{
        page:             page,
        per_page:         per_page,
        car_id:           car_id,
        mileage:          false,
        preload:          @preload,
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
      #Admins.subscribe()
      #UserRoles.subscribe()
      #Roles.subscribe()
      #CompanyPermissions.subscribe()
    end

    socket
    |> assign(:modal,            modal)
    |> assign(:parent,           parent)
    |> assign(:car_id,           Map.get(modal.opts, :car_id))
    |> assign(:user,             modal.user)
    |> assign(:page,             0)
    |> assign(:per_page,         30)
    |> assign(:items,            [])
    |> assign(:changeset,        @module.new_changeset())
    |> assign(:new,              true)
    |> assign(:edit,             true)
    |> assign(:view,             true)
    |> fetch_items()
    |> res(:ok)
  end

  @impl true
  def handle_info({[_, :created], item}, socket) do
    cond do
      (item.car_id == socket.assigns.car_id && !is_nil(item.car_id)) || (item.fixed_car_id == socket.assigns.fixed_car_id && !is_nil(item.fixed_car_id)) ->
        %{items: items} = socket.assigns
        socket |> assign(:items, [item |> @module.preload_associations(%{preload: @preload}) | items] |> Enum.uniq_by(&(&1.id)))
      true -> socket
    end |> res()
  end
  @impl true
  def handle_info({[_, :updated], item}, socket) do
    cond do
      (item.car_id == socket.assigns.car_id && !is_nil(item.car_id)) || (item.fixed_car_id == socket.assigns.fixed_car_id && !is_nil(item.fixed_car_id)) ->
        %{items: items} = socket.assigns
        socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item |> @module.preload_associations(%{preload: @preload}), else: &1)))
      true -> socket
    end |> res()
  end
  @impl true
  def handle_info({[_, :deleted], item}, socket) do
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
  def handle_event("cancel_edit", _, socket), do: socket |> assign(:changeset, @module.new_changeset(%{entry_date: Date.utc_today()})) |> assign(:new, true) |> res()

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
