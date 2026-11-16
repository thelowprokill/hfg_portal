defmodule HfgPortalWeb.Apis.HommSavesController do
  use HfgPortalWeb, :controller

  alias HommSaves.SaveFiles

  @routes [
    %{name: "changes", method: "GET", function: &__MODULE__.get_changes/2, role: :edit, description: "List files changed since `since` by other machines"},
    %{name: "file",    method: "GET", function: &__MODULE__.get_file/2,    role: :edit, description: "Download a save file by `path`"},
    %{name: "file",    method: "PUT", function: &__MODULE__.put_file/2,    role: :edit, description: "Upload (create or overwrite) a save file"},
  ]

  # RoutesController forwards the router's action atom (:call) as the 2nd arg, so read params off the conn
  def call(%{method: method, query_params: %{"route" => route}} = conn, _action) do
    params = conn.params

    case Enum.find(@routes, &(&1.name == route && &1.method == method)) do
      nil ->
        conn |> put_status(:not_found) |> json(%{error: "Route not found"})

      %{function: fun} = route_config ->
        cond do
          not authorized?(conn, route_config) -> conn |> put_status(401) |> json(%{error: "Unauthorized"})
          blank?(params["machine"])           -> conn |> put_status(400) |> json(%{error: "machine is required"})
          true                                -> fun.(conn, params)
        end
    end
  end
  def call(conn, _params), do: conn |> put_status(:not_found) |> json(%{error: "Route not found"})

  defp authorized?(conn, %{role: required_role}) do
    case HommSaves.UserRoles.get(conn.assigns.current_api_user.id, :user) do
      nil       -> false
      user_role -> Map.get(HommSaves.Users.Roles.get(user_role.role), required_role, false)
    end
  end

  defp blank?(v), do: not is_binary(v) or String.trim(v) == ""

  def get_changes(conn, %{"machine" => machine} = params) do
    case parse_since(params["since"]) do
      {:ok, since} ->
        files =
          SaveFiles.changed_since(since, machine)
          |> Enum.map(&%{path: &1.path, updated_at: &1.updated_at, machine: &1.machine})

        json(conn, %{response: :ok, date: DateTime.utc_now(), data: files})

      :error ->
        conn |> put_status(400) |> json(%{error: "since must be ISO8601, e.g. 2026-11-16T12:00:00Z"})
    end
  end

  defp parse_since(nil), do: {:ok, nil}
  defp parse_since(""),  do: {:ok, nil}
  defp parse_since(s) do
    case DateTime.from_iso8601(s) do
      {:ok, dt, _} -> {:ok, dt}
      _            -> :error
    end
  end

  def get_file(conn, params) do
    with {:ok, rel, abs} <- SaveFiles.abs_path(params["path"]),
         true            <- File.regular?(abs) do
      send_download(conn, {:file, abs}, filename: Path.basename(rel))
    else
      :error -> conn |> put_status(400) |> json(%{error: "invalid path"})
      false  -> conn |> put_status(404) |> json(%{error: "file not found"})
    end
  end

  def put_file(conn, %{"machine" => machine} = params) do
    with {:ok, rel, abs}                   <- SaveFiles.abs_path(params["path"]),
         %Plug.Upload{path: tmp}           <- params["file"],
         :ok                               <- File.mkdir_p(Path.dirname(abs)),
         :ok                               <- File.cp(tmp, abs),
         {:ok, file}                       <- SaveFiles.upsert(rel, machine) do
      json(conn, %{response: :ok, date: DateTime.utc_now(), data: %{path: file.path, updated_at: file.updated_at}})
    else
      :error            -> conn |> put_status(400) |> json(%{error: "invalid path"})
      {:error, reason}  -> conn |> put_status(500) |> json(%{error: inspect(reason)})
      _                 -> conn |> put_status(400) |> json(%{error: "file upload is required"})
    end
  end
end
