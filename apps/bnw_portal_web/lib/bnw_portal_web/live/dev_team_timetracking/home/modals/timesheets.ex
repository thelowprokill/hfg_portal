defmodule BnwPortalWeb.DevTeamTimetracking.Home.Modals.ChangeTimesheets do
  use BnwPortalWeb, :live_view

  alias DevTeamTimetracking.{
    Timesheets,
  }

  @module  DevTeamTimetracking.Timesheets
  @key     "timesheet"
  @section "timesheets"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="timesheets_modal" width="w-full xl:w-2/3">
          <.bnw_modal_header><%= @modal.opts.project_name %> - Timesheets</.bnw_modal_header>
          <.bnw_modal_body>
            <.form :let={f}
              for={@changeset}
              phx-change="validate"
              phx-submit="save">
              <.bnw_table height="60vh" id="timesheets_table">
                <:header>
                  <th class="p-2">User</th>
                  <th class="p-2">Date</th>
                  <th class="p-2">Start</th>
                  <th class="p-2">End</th>
                  <th class="p-2">Time</th>
                  <th class="p-2">Task</th>
                  <th class="p-2">Comments</th>
                  <%= if @edit do %>
                    <th class="p-2"></th>
                    <th class="p-2"></th>
                  <% end %>
                </:header>

                <tr id="new_item">
                  <%= if @new && @edit do %>
                    <.edit_form 
                      f={f} 
                      project_id={@project_id} 
                      fixed_project_id={@fixed_project_id} 
                      user_id={@user.id} 
                      user_name={"#{@user.last_name}, #{@user.first_name}"} 
                    />
                  <% end %>
                </tr>

                <%= for item <- @items do %>
                  <tr id={"item_#{item.id}"}>
                    <%= cond do %>
                      <% !@new && @edit && item.id == @changeset.data.id -> %>
                        <.edit_form 
                          f={f} 
                          project_id={@project_id} 
                          fixed_project_id={@fixed_project_id} 
                          user_id={@user.id} 
                          user_name={"#{@user.last_name}, #{@user.first_name}"} 
                          cancel={true} 
                        />
                      <% true -> %>
                        <td class="px-2"><%= item.user.last_name %>, <%= item.user.first_name %></td>
                        <td class="px-2"><%= item.entry_date %></td>
                        <td class="px-2"><%= if item.start do %><.show_time hour={item.start.hour} minute={item.start.minute} /><% end %></td>
                        <td class="px-2"><%= if item.end do %><.show_time hour={item.end.hour} minute={item.end.minute} /><% end %></td>
                        <td class="px-2"><.show_time hour={item.hours} minute={item.minutes} /></td>
                        <td class="px-2"><%= item.task_key %></td>
                        <td class="px-2"><%= item.comments %></td>
                        <%= cond do %>
                          <% @edit && @user.id == item.user_id -> %>
                            <td><.bnw_button_edit   phx-value-id={item.id} /></td>
                            <td><.bnw_button_delete phx-value-id={item.id} /></td>
                          <% @edit -> %>
                            <td></td>
                            <td></td>
                          <% true -> %>
                            <% nil %>
                        <%= end %>
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


  attr :hour,   :any
  attr :minute, :any
  def show_time(assigns) when is_binary(assigns.hour) and is_binary(assigns.minute) do
    ~H"""
      <%= if @hour && @minute, do: '#{@hour}:#{String.pad_leading(@minute, 2, "0")}' %>
    """
  end
  def show_time(assigns) when is_integer(assigns.hour) and is_integer(assigns.minute) do
    show_time(%{hour: Integer.to_string(assigns.hour), minute: Integer.to_string(assigns.minute)})
  end
  def show_time(assigns), do: ~H""

  attr :f,                :any, required: true
  attr :project_id,       :integer
  attr :fixed_project_id, :integer
  attr :user_id,          :integer
  attr :user_name,        :string
  attr :cancel,           :boolean, default: false
  def edit_form(assigns) do
    ~H"""
      <.bnw_input_hidden f={@f} field={:project_id}       value={@project_id} />
      <.bnw_input_hidden f={@f} field={:fixed_project_id} value={@fixed_project_id} />
      <.bnw_input_hidden f={@f} field={:user_id}          value={@user_id} />
      <td class="px-2"><%= @user_name %></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="date" field={:entry_date} display_name="Date"/></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="time" field={:start}      display_name="Start" step="60"/></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="time" field={:end}        display_name="End"   step="60"/></td>
      <td class="px-2"><.show_time hour={Map.get(@f.source.changes, :hours, Map.get(@f.source.data, :hours))} minute={Map.get(@f.source.changes, :minutes, Map.get(@f.source.data, :minutes))} /></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="text" field={:task_key}   display_name="Task"/></td>
      <td class="px-2"><.bnw_input_naked f={@f} type="text" field={:comments}   display_name="Comments"/></td>
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

  defp fetch_user_permissions(socket) do
    %{
      modal:      %{user: user},
      project_id: project_id
    } = socket.assigns
    cond do 
      (user.dev_admin && user.admin_mode) || True -> #|| Admins.is_admin(user.id) -> 
        socket |> assign(:edit, true) |> assign(:view, true)
      true ->
        %{project_permissions: project_permissions} = UserRoles.fetch_user_permissions(user.id)

        edit = Enum.any?(project_permissions, &(&1.project_id == project_id && &1.section == @section && &1.permission in ["admin", "edit"]))
        view = Enum.any?(project_permissions, &(&1.project_id == project_id && &1.section == @section))
        socket |> assign(:edit, edit) |> assign(:view, view)
    end
  end

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
      page:             page,
      per_page:         per_page,
      items:            items,
      project_id:       project_id,
      fixed_project_id: fixed_project_id
    } = socket.assigns

    socket |> assign(:items, items ++ @module.list(
      %{
        page:             page,
        per_page:         per_page,
        project_id:       project_id,
        fixed_project_id: fixed_project_id,
        preload:          [:user],
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
    |> assign(:project_id,       Map.get(modal.opts, :project_id))
    |> assign(:fixed_project_id, Map.get(modal.opts, :fixed_project_id))
    |> assign(:user,             modal.user)
    |> assign(:page,             0)
    |> assign(:per_page,         30)
    |> assign(:items,            [])
    |> assign(:changeset,        @module.new_changeset(%{entry_date: Date.utc_today()}))
    |> assign(:new,              true)
    |> assign(:edit,             false)
    |> assign(:view,             false)
    |> fetch_items()
    |> fetch_user_permissions()
    |> res(:ok)
  end

  @impl true
  def handle_info({[_, :created], item}, socket) do
    cond do
      (item.project_id == socket.assigns.project_id && !is_nil(item.project_id)) || (item.fixed_project_id == socket.assigns.fixed_project_id && !is_nil(item.fixed_project_id)) ->
        %{items: items} = socket.assigns
        socket |> assign(:items, [item |> Timesheets.preload(%{preload: [:user]}) | items] |> Enum.uniq_by(&(&1.id)))
      true -> socket
    end |> res()
  end
  @impl true
  def handle_info({[_, :updated], item}, socket) do
    cond do
      (item.project_id == socket.assigns.project_id && !is_nil(item.project_id)) || (item.fixed_project_id == socket.assigns.fixed_project_id && !is_nil(item.fixed_project_id)) ->
        %{items: items} = socket.assigns
        socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item |> Timesheets.preload(%{preload: [:user]}), else: &1))) |> res()
      true -> socket
    end |> res()
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
