defmodule ItBudget.Budgets.Budget do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_portal_it_budget"
  prefix = case Application.compile_env(:it_budget, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "budgets" do
    field :year,        :integer
    field :description, :string
    field :active,      :boolean, default: true
    belongs_to :user,   BnwPortal.Accounts.User

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :year,
      :description,
      :active,
      :user_id,
    ])
    |> validate_required([:year])
    |> unique_constraint(:year, name: :uk_budget)
  end
end

