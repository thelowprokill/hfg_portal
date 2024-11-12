defmodule WifeTime.WifeTimes.WifeTime do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_wife_time"
  prefix = case Application.compile_env(:wife_time, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "wife_times" do
    field :entry_date,  :date
    field :happened,    :boolean
    field :menstration, :boolean
    field :comment,     :string

    belongs_to :created_by, WifeTime.Users.User
    belongs_to :updated_by, WifeTime.Users.User

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :entry_date,
      :happened,
      :menstration,
      :comment,
      :created_by_id,
      :updated_by_id,
    ])
  end
end
