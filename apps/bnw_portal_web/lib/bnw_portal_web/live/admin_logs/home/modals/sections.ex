defmodule BnwPortalWeb.AdminLogs.Home.Modals.ChangeSections do
  use BnwPortalWeb, :live_view

  @module  AdminLogs.HiddenSections
  @key     "hidden_section"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="hidden_section_modal">
        <.bnw_modal_header>Hidden Sections</.bnw_modal_header>
        <.bnw_modal_body>
          <.bnw_table height="60vh" id="hidden_section_table" load_more={false}>
            <:header>
              <th class="p-2 w-1/3">Section</th>
              <th class="p-2 w-1/3">Show</th>
            </:header>

            <%= for %{id: id, name: name} <- @sections do %>
              <% selected = !Enum.any?(@items, &(&1.section == id)) %>
              <tr>
                <td><%= name %></td>
                <td><.bnw_button_toggle_active phx-value-section={id} active={selected} /></td>
              </tr>
            <% end %>
            
          </.bnw_table>
        </.bnw_modal_body>
        <.bnw_modal_footer><.bnw_button_done id="a_different_done"/></.bnw_modal_footer>
      </.bnw_modal>
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
    %{modal: %{user: user}} = socket.assigns

    socket |> assign(:items, @module.list(%{user_id: user.id}))
  end

  defp fetch_sections(socket), do: socket |> assign(:sections, @module.list_sections())

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
    end

    socket
    |> assign(:modal,         modal)
    |> assign(:parent,        parent)
    |> assign(:items,         [])
    |> assign(:permissions,   [])
    |> assign(:perms,         [])
    |> assign(:edit,          false)
    |> assign(:view,          false)
    |> fetch_sections()
    |> fetch_items()
    |> res(:ok)
  end

  #items
  @impl true 
  def handle_info({[:hidden_section, :created], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, [item | items]) |> res()
  end
  @impl true
  def handle_info({[:hidden_section, :updated], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:hidden_section, :deleted], item}, socket) do
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
  def handle_event("cancel", _, socket) do
    cancel(socket) |> res()
  end

  @impl true
  def handle_event("activate", %{"section" => section}, socket) do
    %{
      modal: %{user: user},
    } = socket.assigns

    @module.delete(user.id, section)

    socket |> res()
  end

  @impl true
  def handle_event("deactivate", %{"section" => section}, socket) do
    %{
      modal: %{user: user},
    } = socket.assigns

    @module.new()
    |> @module.create_or_update(
      %{
        user_id: user.id,
        section: section
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
