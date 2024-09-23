defmodule AdminLogs.PythonScripts.PythonScriptError do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_portal_admin_logs"
  prefix = case Application.compile_env(:admin_logs, :env) do
             :dev -> prefix <> "_dev"
             :test -> prefix <> "_test"
             _ -> prefix
           end

  @schema_prefix prefix

  schema "python_script_errors" do
    field :errors, :integer
    belongs_to :python_script, AdminLogs.PythonScripts.PythonScript

    timestamps()
  end

  def changeset(plug, attrs \\ %{}) do
    plug
    |> cast(attrs, [
      :errors,
      :python_script_id
    ])
  end
end
