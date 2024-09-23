defmodule AdminLogs.PythonScripts.PythonScript do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_portal_admin_logs"
  prefix = case Application.compile_env(:admin_logs, :env) do
             :dev -> prefix <> "_dev"
             :test -> prefix <> "_test"
             _ -> prefix
           end

  @schema_prefix prefix

  schema "python_scripts" do
    field :name,       :string
    field :sub_script, :string
    field :run_type,   :string
    field :duration,   :integer
    field :off_start,  :integer
    field :off_end,    :integer
    field :count,      :integer

    timestamps()
  end

  def changeset(plug, attrs \\ %{}) do
    plug
    |> cast(attrs, [
      :name,
      :sub_script,
      :run_type,
      :duration,
      :off_start,
      :off_end,
      :count,
    ])
  end
end
