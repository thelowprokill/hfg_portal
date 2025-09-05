defmodule HfgPortalWeb.CarMaintenance.Home.Modals.ChangeMaintenanceImages do
  use HfgPortalWeb, :live_view

  @module  CarMaintenance.MaintenanceImages
  @key     "maintenance_image"
  @preload []

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="maintenance_images_modal" width="w-2/3">
          <.bnw_modal_header><%= if @service_history.named_item, do: @service_history.name, else: @service_history.maintenance_item.name %> - Maintenance Images</.bnw_modal_header>
          <.bnw_modal_body>
            <.form :let={f}
              for={@changeset}
              phx-change="validate"
              phx-submit="save">
              <.bnw_table height="60vh" id="timesheets_table">
                <:header>
                  <.bnw_th>Name</.bnw_th>
                  <.bnw_th>Image</.bnw_th>
                  <.bnw_th></.bnw_th>
                </:header>

                <tr id="new_image">
                  <%= if @new && @edit do %>
                    <.edit_form 
                      f={f} 
                      service_history_id={@service_history_id} 
                      uploads={@uploads}
                      user_id={@user.id} 
                    />
                  <% end %>
                </tr>

                <%= for image <- @images do %>
                  <tr id={"image_#{image.id}"}>
                    <td class="px-2"><%= image.name %></td>
                    <td class="px-2"><img src={~p"/car_maitenance_images/#{image.id}/image"} width="500" /></td>
                    <td class="px-2"></td>
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

  attr :f,                   :any, required: true
  attr :service_history_id, :integer
  attr :user_id,             :integer
  attr :cancel,              :boolean, default: false
  attr :uplads,              :any, required: true
  def edit_form(assigns) do
    ~H"""
      <.bnw_input_hidden f={@f} field={:created_by_id} value={@user_id} />
      <.bnw_input_hidden f={@f} field={:service_history_id} value={@service_history_id} />
      <.bnw_input_hidden f={@f} field={:updated_by_id} value={@user_id} />

      <td class="px-2"><.bnw_input_naked f={@f} type="text"     field={:name}            display_name="Name"/></td>
      <td class="px-2"><.live_file_input upload={@uploads.image} /></td>
      <td class="px-2"><.bnw_button_submit /></td>
    """
  end

  attr :active,  :boolean, default: false
  attr :image_id, :integer
  def toggle_active(assigns) when assigns.active, do: ~H"""
    <.bnw_button_icon
      class='text-success-main hover:text-success-hover' 
      bnw_icon='check'
      phx-value-id={@image_id}
      phx_click='deactivate'
    />
    """
  def toggle_active(assigns), do: ~H"""
    <.bnw_button_icon
      class='text-danger-main hover:text-danger-hover' 
      bnw_icon='ban'
      phx-value-id={@image_id}
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

  defp fetch_images(socket) do
    %{
      page:     page,
      per_page: per_page,
      images:   images,
      service_history_id: service_history_id,
    } = socket.assigns

    socket |> assign(:images, images ++ @module.list(
      %{
        page:                page,
        per_page:            per_page,
        service_history_id: service_history_id,
        mileage:             false,
        preload:             @preload,
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end

  defp fetch_service_history(socket) do
    %{service_history_id: service_history_id} = socket.assigns
    socket 
    |> assign(
      :service_history, 
      CarMaintenance.ServiceHistories.get(service_history_id)
      |> CarMaintenance.ServiceHistories.preload_associations(%{preload: [:maintenance_item]})
    )
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
    |> allow_upload(:image, accept: ~w(.jpg .jpeg .png), max_entries: 1)
    |> assign(:modal,               modal)
    |> assign(:parent,              parent)
    |> assign(:service_history_id,  Map.get(modal.opts, :service_history_id))
    |> assign(:user,                modal.user)
    |> assign(:page,                0)
    |> assign(:per_page,            30)
    |> assign(:images,               [])
    |> assign(:changeset,           @module.new_changeset())
    |> assign(:new,                 true)
    |> assign(:edit,                true)
    |> assign(:view,                true)
    |> fetch_images()
    |> fetch_service_history()
    |> res(:ok)
  end

  @impl true
  def handle_info({[_, :created], image}, socket) do
    cond do
      (image.service_history_id == socket.assigns.service_history_id && !is_nil(image.service_history_id)) || (image.fixed_service_history_id == socket.assigns.fixed_service_history_id && !is_nil(image.fixed_service_history_id)) ->
        %{images: images} = socket.assigns
        socket |> assign(:images, [image |> @module.preload_associations(%{preload: @preload}) | images] |> Enum.uniq_by(&(&1.id)))
      true -> socket
    end |> res()
  end
  @impl true
  def handle_info({[_, :updated], image}, socket) do
    cond do
      (image.service_history_id == socket.assigns.service_history_id && !is_nil(image.service_history_id)) || (image.fixed_service_history_id == socket.assigns.fixed_service_history_id && !is_nil(image.fixed_service_history_id)) ->
        %{images: images} = socket.assigns
        socket |> assign(:images, Enum.map(images, &(if &1.id == image.id, do: image |> @module.preload_associations(%{preload: @preload}), else: &1)))
      true -> socket
    end |> res()
  end
  @impl true
  def handle_info({[_, :deleted], image}, socket) do
    %{images: images} = socket.assigns
    socket |> assign(:images, Enum.reject(images, &(&1.id == image.id))) |> res()
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

    uploaded_file = consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
      ext = Path.extname(entry.client_name)
      dest = Path.join(Application.app_dir(:hfg_portal_web, "priv/uploads"), Path.basename(path))
      dest = dest <> ext
      File.cp!(path, dest)
      {:ok, %{type: ext, dest: dest}}
    end)
    |> Enum.at(0)

    binary = File.read!(uploaded_file.dest)
    File.rm(uploaded_file.dest)

    changeset =
      changeset.data
      |> @module.change(params |> Map.get(@key, %{}) |> Map.put("image", binary) |> Map.put("image_content_type", String.trim_leading(uploaded_file.type, ".")))
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
    |> fetch_images()
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
