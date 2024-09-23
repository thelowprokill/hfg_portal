defmodule BnwPortal.Accounts.Location do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_portal"
  prefix = case Application.compile_env(:bnw_portal, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "locations" do
    field :name,       :string
    field :short_name, :string
    field :active,     :boolean, default: true

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :short_name,
      :active,
    ])
    |> validate_required([:name])
  end
end



