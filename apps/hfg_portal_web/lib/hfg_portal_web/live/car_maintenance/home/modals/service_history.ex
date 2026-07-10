defmodule HfgPortalWeb.CarMaintenance.Home.Modals.ChangeServiceHistory do
  use HfgPortalWeb, :live_view

  @module  CarMaintenance.ServiceHistories
  @key     "service_history"
  @preload [:maintenance_item]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="service_history_modal" width="w-full">
          <.bnw_modal_header><%= @modal.opts.car.name %> - Service History</.bnw_modal_header>
          <.bnw_modal_body>
            <.form :let={f}
              for={@changeset}
              phx-change="validate"
              phx-submit="save">
              <.bnw_table height="60vh" id="service_history_table_main">
                <:header>
                  <th class="p-2">Service History</th>
                  <th class="p-2">Maintenance Scedule</th>
                </:header>

                <tr>
                  <td class="p-2">
                    <.bnw_table height="60vh" id="service_history_table">
                      <:header>
                        <th class="p-2">Service Date</th>
                        <th class="p-2">Service Mileage</th>
                        <th class="p-2"></th>
                        <th class="p-2">Service Item</th>
                        <th class="p-2">Next Serviec Due</th>
                        <th class="p-2">Service Notes</th>
                        <th class="p-2"></th>
                      </:header>

                      <tr id="new_item">
                        <%= if @new && @edit do %>
                          <.edit_form
                            f={f}
                            car_id={@car_id}
                            user_id={@user.id}
                            new={true}
                            maintenance_items_list={@maintenance_items_list}
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
                                maintenance_items_list={@maintenance_items_list}
                              />
                            <% true -> %>
                              <td class="px-2"><%= item.service_date %></td>
                              <td class="px-2 text-right"><%= item.mileage |> Number.Delimit.number_to_delimited(precision: 0) %></td>
                              <td class="px-2"></td>
                              <td class="px-2"><%= if item.named_item, do: item.name, else: item.maintenance_item.name %></td>
                              <td class="px-2 text-right">
                                <%= cond do %>
                                  <% !item.named_item && item.maintenance_item.interval_miles -> %>
                                    <%= item.mileage + item.maintenance_item.interval_miles %>
                                  <% !item.named_item && item.maintenance_item.interval_months -> %>
                                    <%= item.service_date |> Date.add(item.maintenance_item.interval_months * 30) %>
                                  <% true -> %>
                                    <%= nil %>
                                <% end %>
                              </td>
                              <td class="px-2"><%= item.notes %></td>
                              <td class="px-2"><.bnw_button_default phx_click="maintenance_images" phx-value-id={item.id}>Images</.bnw_button_default></td>
                          <% end %>
                        </tr>
                      <% end %>
                    </.bnw_table>
                  </td>
                  <td class="p-2">
                    <.bnw_table height="60vh" id="service_history_table">
                      <:header>
                        <th class="px-2">Last Service Date</th>
                        <th class="px-2">Service Item</th>
                        <th class="px-2">Next Service Due</th>
                        <th class="px-2">Notes</th>
                      </:header>
                      <%= for item <- @maintenance_items do %>
                        <tr id={"maintenance_item_#{item.id}"}>
                          <td class="px-2"><%= if item.last_service_history, do: item.last_service_history.service_date %></td>
                          <td class="px-2"><%= item.name %></td>
                          <td class="px-2 text-right">
                            <%= cond do %>
                              <% item.interval_miles -> %>
                                <%= (if item.last_service_history, do: item.last_service_history.mileage, else: 0) + item.interval_miles |> Number.Delimit.number_to_delimited(precision: 0) %>
                              <% item.interval_months && item.last_service_history -> %>
                                <%= item.last_service_history.service_date |> Date.add(item.interval_months * 30) %>
                              <% true -> %>
                                <%= nil %>
                            <% end %>
                          </td>
                          <td class="px-2"><%= item.notes %></td>
                        </tr>
                      <% end %>
                    </.bnw_table>
                  </td>
                </tr>
              </.bnw_table>
            </.form>
          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_done /></.bnw_modal_footer>
        </.bnw_modal>
      <% end %>
      <.bnw_modal_render socket={@socket} modal_stack={@modal_stack} />
    </div>
    """
  end

  attr :f,                 :any, required: true
  attr :car_id,            :integer
  attr :user_id,           :integer
  attr :user_name,         :string
  attr :new,               :boolean, default: false
  attr :maintenance_items_list, :list
  def edit_form(assigns) do
    ~H"""
      <%= if @new do %>
        <.bnw_input_hidden f={@f} field={:created_by_id} value={@user_id} />
      <% end %>
      <.bnw_input_hidden f={@f} field={:car_id}        value={@car_id} />
      <.bnw_input_hidden f={@f} field={:updated_by_id} value={@user_id} />
      <td class="px-2"><.bnw_input_naked f={@f} type="date"     field={:service_date} display_name="Service Date" /></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="number"   field={:mileage}      display_name="Service Mileage"/></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="checkbox" field={:named_item}   display_name="Named Item"/></td>
      <td class="px-2">
        <%= if @f.params |> Map.get("named_item", "#{Map.get(@f.data, :named_item)}") == "true" do %>
          <.bnw_input_naked f={@f} type="text"     field={:name}          display_name="Service Item"/>
        <% else %>
          <.bnw_input_naked f={@f} type="select"   field={:maintenance_item_id} display_name="Service Item" list={@maintenance_items_list} />
        <% end %>
      </td>
      <td class="px-2"></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="text"     field={:notes}        display_name="Notes"/></td>
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
    %{changeset: changeset, modal: modal} = socket.assigns
    cond do
      changeset.valid? ->
        changeset.data |> @module.create_or_update(changeset.changes)
        |> case do
          {:ok, data} -> 
            socket 
            |> assign(:changeset, @module.new_changeset(
              %{
                service_date: DateTime.utc_now() |> DateTime.from_naive!("Etc/UTC") |> DateTime.shift_zone!("America/Los_Angeles"), 
                mileage: cond do
                  modal.opts.car.service_history && data.mileage && data.mileage > modal.opts.car.service_history.mileage -> data.mileage
                  modal.opts.car.service_history -> modal.opts.car.service_history.mileage
                  data.mileage -> data.mileage
                  true -> 0
                end
              })) 
            |> assign(:new, true)
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

  defp fetch_maintenance_items(socket) do
    %{ car_id: car_id } = socket.assigns

    maintenance_items = CarMaintenance.MaintenanceItems.list(%{
      car_id: car_id, 
      active: true,
      preload: [last_service_history: @module.service_history_query()],
    })

    socket 
    |> assign(:maintenance_items, maintenance_items)
    |> assign(:maintenance_items_list, maintenance_items |> Enum.map(&([key: &1.name, value: &1.id])))
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
    |> assign(:car_id,           modal.opts.car.id)
    |> assign(:user,             modal.user)
    |> assign(:page,             0)
    |> assign(:per_page,         30)
    |> assign(:items,            [])
    |> assign(:maintenance_items_list, [])
    |> assign(:modal_stack,      [])
    |> assign(:changeset,        @module.new_changeset(
      %{
        service_date: DateTime.utc_now() |> DateTime.from_naive!("Etc/UTC") |> DateTime.shift_zone!("America/Los_Angeles"),
        mileage: if(modal.opts.car.service_history, do: modal.opts.car.service_history.mileage, else: 0),
      }))
    |> assign(:new,              true)
    |> assign(:edit,             true)
    |> assign(:view,             true)
    |> fetch_items()
    |> fetch_maintenance_items()
    |> res(:ok)
  end

  @impl true
  def handle_info({[_, :created], item}, socket) do
    cond do
      (item.car_id == socket.assigns.car_id && !is_nil(item.car_id)) ->
        %{items: items} = socket.assigns
        socket |> assign(:items, [item |> @module.preload(%{preload: @preload}) | items] |> Enum.uniq_by(&(&1.id)))
      true -> socket
    end |> res()
  end
  @impl true
  def handle_info({[_, :updated], item}, socket) do
    cond do
      (item.car_id == socket.assigns.car_id && !is_nil(item.car_id)) || (item.fixed_car_id == socket.assigns.fixed_car_id && !is_nil(item.fixed_car_id)) ->
        %{items: items} = socket.assigns
        socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item |> @module.preload(%{preload: @preload}), else: &1)))
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
  def handle_event("maintenance_images", %{"id" => id}, socket) do
    %{parent: parent} = socket.assigns
    send(parent, {:maintenance_images, id |> String.to_integer()})
    socket |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
