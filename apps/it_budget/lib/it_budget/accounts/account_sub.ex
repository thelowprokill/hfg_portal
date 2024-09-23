defmodule ItBudget.Accounts.AccountSub do
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

  schema "account_subs" do
    field :name,         :string
    belongs_to :account, ItBudget.Accounts.Account
    field :locked,       :boolean

    field :description,  :string
    field :active,       :boolean, default: true
    belongs_to :user,    BnwPortal.Accounts.User

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :name,
      :account_id,
      :locked,
      :description,
      :active,
      :user_id,
    ])
    |> validate_required([:name])
    |> unique_constraint([:name, :account_id], name: :uk_acc_sub)
  end
end



