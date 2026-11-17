defmodule HfgPortalWeb.HommSaves.Files.FilesLive do
  use HfgPortalWeb, :live_view

  alias HommSaves.SaveFiles
  alias HommSaves.SaveFiles.SaveFile

  @section_titles [{"saves", "Save Games"}, {"templates", "RMG Templates"}]
  @per_page 50

  # Each section tracks how many rows it has loaded (`limits`); reloading re-queries that many,
  # so live updates and deletes stay consistent without merging pages.
  defp fetch_files(socket) do
    limits = socket.assigns.limits

    sections =
      for {section, title} <- @section_titles do
        limit = Map.fetch!(limits, section)
        # fetch one extra row to know whether there is another page
        files = SaveFiles.list(section, limit + 1)

        %{
          id:          section,
          title:       title,
          tree:        files |> Enum.take(limit) |> build_tree(),
          has_more:    length(files) > limit,
          last_upload: SaveFiles.last_upload(section),
        }
      end

    socket |> assign(:sections, sections)
  end

  # "a/b/c.GM1" -> %{"a" => %{"b" => %{"c.GM1" => %SaveFile{}}}}
  defp build_tree(files), do: Enum.reduce(files, %{}, &put_in_tree(&2, String.split(&1.path, "/"), &1))

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
              <.bnw_button_delete phx-value-section={@section} phx-value-path={entry.path} data={[confirm: "Delete #{entry.path}?"]} />
            </div>
          <% else %>
            <details open>
              <summary class="cursor-pointer font-semibold py-0.5">
                <%= name %>/
                <.bnw_button_delete phx-value-section={@section} phx-value-path={@prefix <> name} data={[confirm: "Delete folder #{@prefix <> name} and everything in it?"]} />
              </summary>
              <.tree tree={entry} section={@section} prefix={@prefix <> name <> "/"} />
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
    |> assign(:limits, Map.new(@section_titles, fn {section, _} -> {section, @per_page} end))
    |> fetch_files()
    |> res(:ok)
  end

  @impl true
  def handle_info({[:homm_saves, :save_file, _], _file}, socket), do: socket |> fetch_files() |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("delete", %{"section" => section, "path" => path}, socket) do
    case SaveFiles.delete(section, path) do
      {:ok, _n} -> socket
      _error    -> socket |> put_flash(:error, "Could not delete #{path}")
    end
    |> fetch_files()
    |> res()
  end

  @impl true
  def handle_event("load_more", %{"section" => section}, socket) do
    socket
    |> update(:limits, &Map.update!(&1, section, fn n -> n + @per_page end))
    |> fetch_files()
    |> res()
  end

  @impl true
  def handle_event("refresh", _, socket), do: socket |> fetch_files() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
