defmodule ItBudget.Accounts.Account do
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

  schema "accounts" do
    field :name, :string
    field :code, :string

    field :description, :string
    field :active,      :boolean, default: true
    belongs_to :user,   BnwPortal.Accounts.User

    has_many :account_subs, ItBudget.Accounts.AccountSub

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :code,
      :description,
      :active,
      :user_id,
    ])
    |> validate_required([:name])
    |> unique_constraint(:name, name: :uk_acc)
    |> unique_constraint(:code, name: :uk_acc_code)
  end
end


