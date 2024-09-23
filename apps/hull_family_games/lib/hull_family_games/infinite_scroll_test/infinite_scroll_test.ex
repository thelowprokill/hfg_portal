defmodule HullFamilyGames.InfiniteScrollTest.Item do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hull_family_games"
  prefix = case Application.compile_env(:hull_family_games, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "infinite_scroll_test" do
    field :name,        :string

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
    ])
    |> validate_required([:name])
  end
end


