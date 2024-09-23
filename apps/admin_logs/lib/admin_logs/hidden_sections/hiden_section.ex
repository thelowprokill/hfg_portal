defmodule AdminLogs.HiddenSections.HiddenSection do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_portal_admin_logs"
  prefix = case Application.compile_env(:admin_logs, :env) do
             :dev -> prefix <> "_dev"
             :test -> prefix <> "_test"
             _ -> prefix
           end

  @schema_prefix prefix

  schema "hidden_sections" do
    belongs_to :user, AdminLogs.Users.User
    field :section, :string

    timestamps()
  end

  def changeset(plug, attrs \\ %{}) do
    plug
    |> cast(attrs, [
      :user_id,
      :section
    ])
  end
end
