defmodule ItBudget.Reports.Report do
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

  schema "reports" do
    belongs_to :user, BnwPortal.Accounts.User
    field :report_name, :string
    field :report_url,  :string
    field :active,      :boolean, default: true

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :user_id,
      :report_name,
      :report_url,
      :active,
    ])
    |> validate_required([:user_id, :report_name, :report_url])
  end
end

