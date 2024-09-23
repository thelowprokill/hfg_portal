defmodule AdminLogs.TurnkeyUpdates.TurnkeyUpdate do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_portal_admin_logs"
  prefix = case Application.compile_env(:admin_logs, :env) do
             :dev -> prefix <> "_dev"
             :test -> prefix <> "_test"
             _ -> prefix
           end

  @schema_prefix prefix

  schema "turnkey_updates" do
    field :table,  :string
    field :errors, :integer

    timestamps()
  end

  def changeset(plug, attrs \\ %{}) do
    plug
    |> cast(attrs, [
      :table,
      :errors
    ])
  end
end
