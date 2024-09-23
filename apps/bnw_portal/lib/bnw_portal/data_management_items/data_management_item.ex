defmodule BnwPortal.DataManagementItems.DataManagementItem do
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

  schema "data_management_items" do
    field :name,        :string
    field :link,        :string
    field :new_tab,     :boolean, default: true
    field :order,       :integer
    field :group_id,    :integer

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :link,
      :order,
      :new_tab,
      :group_id,
    ])
    |> validate_required([:name, :link, :group_id])
  end
end


