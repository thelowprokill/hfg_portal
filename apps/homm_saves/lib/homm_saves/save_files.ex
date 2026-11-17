defmodule HommSaves.SaveFiles do
  import Ecto.Query
  alias HommSaves.Repo

  defmodule SaveFile do
    use Ecto.Schema

    prefix = "homm_saves"
    prefix = case Application.compile_env(:homm_saves, :env) do
      :dev   -> prefix <> "_dev"
      :test  -> prefix <> "_test"
      :trial -> prefix <> "_trial"
      _      -> prefix
    end

    @schema_prefix prefix

    @timestamps_opts [type: :utc_datetime_usec]
    schema "save_files" do
      field :path,    :string
      field :machine, :string

      timestamps()
    end
  end

  def root, do: System.get_env("HOMM_SAVES_DIR", "/homm_saves")

  def list, do: SaveFile |> order_by(:path) |> Repo.all()

  def changed_since(since, machine) do
    SaveFile
    |> where([f], f.machine != ^machine)
    |> then(fn q -> if since, do: where(q, [f], f.updated_at > ^since), else: q end)
    |> order_by(:path)
    |> Repo.all()
  end

  @topic "homm_saves:save_files"
  def subscribe, do: Phoenix.PubSub.subscribe(HfgPortal.PubSub, @topic)

  def upsert(path, machine) do
    %SaveFile{path: path, machine: machine}
    |> Repo.insert(
      on_conflict:      {:replace, [:machine, :updated_at]},
      conflict_target:  :path,
      returning:        true
    )
    |> tap(fn
      {:ok, file} -> Phoenix.PubSub.broadcast(HfgPortal.PubSub, @topic, {[:homm_saves, :save_file, :upserted], file})
      _           -> :ok
    end)
  end

  @doc "Deletes a file or a whole folder (disk + rows). Returns {:ok, rows_deleted} | :error | {:error, reason}."
  def delete(path) do
    with {:ok, rel, abs} <- abs_path(path),
         {:ok, _}        <- File.rm_rf(abs) do
      # escape LIKE wildcards: save folder names contain "_"
      children = String.replace(rel, ~r/[\\%_]/, "\\\\\\0") <> "/%"
      {n, _} = SaveFile |> where([f], f.path == ^rel or like(f.path, ^children)) |> Repo.delete_all()

      Phoenix.PubSub.broadcast(HfgPortal.PubSub, @topic, {[:homm_saves, :save_file, :deleted], rel})
      {:ok, n}
    else
      {:error, reason, _file} -> {:error, reason}
      :error                  -> :error
    end
  end

  @doc "Relative client path -> {:ok, normalized_rel, abs} or :error if it escapes the root."
  def abs_path(rel) when is_binary(rel) do
    rel = rel |> String.replace("\\", "/") |> String.trim_leading("/")

    case Path.safe_relative(rel) do
      {:ok, safe} when safe not in ["", "."] -> {:ok, safe, Path.join(root(), safe)}
      _                                      -> :error
    end
  end
  def abs_path(_), do: :error
end
