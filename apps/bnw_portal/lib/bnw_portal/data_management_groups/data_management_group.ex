defmodule BnwPortal.DataManagementGroups.DataManagementGroup do
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

  schema "data_management_groups" do
    field :name,     :string
    field :order,    :integer

    has_many :items, BnwPortal.DataManagementItems.DataManagementItem, foreign_key: :group_id

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :order
    ])
    |> validate_required([:name])
  end
end

