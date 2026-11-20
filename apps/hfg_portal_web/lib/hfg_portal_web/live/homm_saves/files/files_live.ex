defmodule HfgPortalWeb.HommSaves.Files.FilesLive do
  use HfgPortalWeb, :live_view

  alias HommSaves.SaveFiles
  alias HommSaves.SaveFiles.SaveFile

  @section_titles [{"saves", "Save Games"}, {"templates", "RMG Templates"}]
  @per_page 50

  # Loaded files live in assigns as section -> %{path => file}: load more fetches only the next
  # page, and each upsert/delete broadcast changes just that file. The tree is built at render.
  defp init_sections(socket) do
    socket
    |> assign(:sections, Enum.map(@section_titles, fn {id, title} -> %{id: id, title: title} end))
    |> assign(:files,       Map.new(@section_titles, fn {id, _} -> {id, %{}} end))
    |> assign(:cursor,      %{})
    |> assign(:has_more,    %{})
    |> assign(:last_upload, Map.new(@section_titles, fn {id, _} -> {id, SaveFiles.last_upload(id)} end))
    |> then(fn socket -> Enum.reduce(@section_titles, socket, fn {id, _}, acc -> load_page(acc, id) end) end)
  end

  defp load_page(socket, section) do
    # fetch one extra row to know whether there is another page
    rows = SaveFiles.list(section, @per_page + 1, socket.assigns.cursor[section])
    page = Enum.take(rows, @per_page)

    socket
    |> update(:files,    &Map.update!(&1, section, fn files -> Enum.into(page, files, fn f -> {f.path, f} end) end))
    |> update(:cursor,   &Map.put(&1, section, List.last(page) || &1[section]))
    |> update(:has_more, &Map.put(&1, section, length(rows) > @per_page))
  end

  # "a/b/c.GM1" -> %{"a" => %{"b" => %{"c.GM1" => %SaveFile{}}}}
  def build_tree(files), do: Enum.reduce(files, %{}, &put_in_tree(&2, String.split(&1.path, "/"), &1))

  defp put_in_tree(tree, [name], file),       do: Map.put(tree, name, file)
  defp put_in_tree(tree, [dir | rest], file), do: Map.update(tree, dir, put_in_tree(%{}, rest, file), &put_in_tree(&1, rest, file))

  # most recent first; a folder sorts by its newest file
  defp sorted_entries(tree), do: Enum.sort_by(tree, fn {_name, v} -> latest(v) end, {:desc, DateTime})

  defp latest(%SaveFile{updated_at: dt}), do: dt
  defp latest(dir), do: dir |> Map.values() |> Enum.map(&latest/1) |> Enum.max(DateTime)

  def format_dt(nil), do: "never"
  def format_dt(dt),  do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")

  attr :tree,    :map,    required: true
  attr :section, :string, required: true
  attr :prefix,  :string, default: ""
  attr :collapsed, :any,  required: true
  def tree(assigns) do
    ~H"""
    <ul class="pl-4">
      <%= for {name, entry} <- sorted_entries(@tree) do %>
        <li>
          <%= if is_struct(entry, SaveFile) do %>
            <div class="flex gap-4 py-0.5">
              <span class="font-mono"><%= name %></span>
              <span class="text-sm text-gray-500"><%= format_dt(entry.updated_at) %></span>
              <span class="text-sm text-gray-500"><%= entry.machine %></span>
              <.bnw_button_delete phx-value-section={@section} phx-value-path={entry.path} item={entry.path} />
            </div>
          <% else %>
            <%!-- open is server state: a re-render (load more, live update) would otherwise reopen it --%>
            <details open={not MapSet.member?(@collapsed, {@section, @prefix <> name})}>
              <summary class="cursor-pointer font-semibold py-0.5" phx-click="toggle" phx-value-section={@section} phx-value-path={@prefix <> name}>
                <%= name %>/
                <.bnw_button_delete phx-value-section={@section} phx-value-path={@prefix <> name} data={[{"confirm-delete", "folder #{@prefix <> name}"}, {"confirm-delete-message", "This deletes everything in it."}]} />
              </summary>
              <.tree tree={entry} section={@section} prefix={@prefix <> name <> "/"} collapsed={@collapsed} />
            </details>
          <% end %>
        </li>
      <% end %>
    </ul>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket), do: SaveFiles.subscribe()

    socket
    |> bnw_verify_user_token(session, "HoMM Saves")
    |> assign(:collapsed, MapSet.new())
    |> init_sections()
    |> res(:ok)
  end

  @impl true
  def handle_info({[:homm_saves, :save_file, :upserted], %SaveFile{} = file}, socket) do
    socket
    |> update(:files,       &Map.update(&1, file.section, %{}, fn files -> Map.put(files, file.path, file) end))
    |> update(:last_upload, &Map.put(&1, file.section, file.updated_at))
    |> res()
  end

  # a folder delete takes everything under it
  @impl true
  def handle_info({[:homm_saves, :save_file, :deleted], {section, path}}, socket) do
    socket
    |> update(:files, &Map.update(&1, section, %{}, fn files ->
      Map.reject(files, fn {p, _} -> p == path or String.starts_with?(p, path <> "/") end)
    end))
    |> update(:last_upload, &Map.put(&1, section, SaveFiles.last_upload(section)))
    |> res()
  end

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("delete", %{"section" => section, "path" => path}, socket) do
    case SaveFiles.delete(section, path) do
      # the :deleted broadcast removes it from the list
      {:ok, _n} -> socket
      _error    -> socket |> put_flash(:error, "Could not delete #{path}")
    end
    |> res()
  end

  # the browser has already toggled the <details>; just remember it
  @impl true
  def handle_event("toggle", %{"section" => section, "path" => path}, socket) do
    key = {section, path}
    socket
    |> update(:collapsed, &if(MapSet.member?(&1, key), do: MapSet.delete(&1, key), else: MapSet.put(&1, key)))
    |> res()
  end

  @impl true
  def handle_event("load_more", %{"section" => section}, socket) do
    socket |> load_page(section) |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
