defmodule HfgPortalWeb.HommSaves.Files.FilesLive do
  use HfgPortalWeb, :live_view

  alias HommSaves.SaveFiles
  alias HommSaves.SaveFiles.SaveFile

  # ponytail: loads every row on mount; fine for a few hundred saves, paginate if it ever grows large
  defp fetch_files(socket) do
    files = SaveFiles.list()

    socket
    |> assign(:tree,        build_tree(files))
    |> assign(:last_upload, files |> Enum.map(& &1.updated_at) |> Enum.max(DateTime, fn -> nil end))
  end

  # "a/b/c.GM1" -> %{"a" => %{"b" => %{"c.GM1" => %SaveFile{}}}}
  defp build_tree(files), do: Enum.reduce(files, %{}, &put_in_tree(&2, String.split(&1.path, "/"), &1))

  defp put_in_tree(tree, [name], file),       do: Map.put(tree, name, file)
  defp put_in_tree(tree, [dir | rest], file), do: Map.update(tree, dir, put_in_tree(%{}, rest, file), &put_in_tree(&1, rest, file))

  # directories first, then files, each alphabetical
  defp sorted_entries(tree), do: Enum.sort_by(tree, fn {name, v} -> {is_struct(v, SaveFile), name} end)

  def format_dt(nil), do: "never"
  def format_dt(dt),  do: Calendar.strftime(dt, "%Y-%m-%d %H:%M:%S UTC")

  attr :tree,   :map,    required: true
  attr :prefix, :string, default: ""
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
              <.bnw_button_delete phx-value-path={entry.path} data={[confirm: "Delete #{entry.path}?"]} />
            </div>
          <% else %>
            <details open>
              <summary class="cursor-pointer font-semibold py-0.5">
                <%= name %>/
                <.bnw_button_delete phx-value-path={@prefix <> name} data={[confirm: "Delete folder #{@prefix <> name} and everything in it?"]} />
              </summary>
              <.tree tree={entry} prefix={@prefix <> name <> "/"} />
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
  def handle_event("delete", %{"path" => path}, socket) do
    case SaveFiles.delete(path) do
      {:ok, _n} -> socket
      _error    -> socket |> put_flash(:error, "Could not delete #{path}")
    end
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
