defmodule Budget.Accounts.Account do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "hfg_portal_budget"

  prefix =
    case Application.compile_env(:budget, :env) do
      :dev -> prefix <> "_dev"
      :test -> prefix <> "_test"
      _ -> prefix
    end

  @schema_prefix prefix

  schema "accounts" do
    field(:user_id, :integer)
    field(:name, :string)
    field(:type, :string)

    timestamps()
  end

  def changeset(account, attrs \\ %{}) do
    account
    |> cast(attrs, [:user_id, :name, :type])
    |> validate_required([:user_id, :name, :type])
    |> validate_inclusion(:type, ["debit", "credit"])
  end
end
