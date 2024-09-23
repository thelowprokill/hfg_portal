defmodule Budget.Reports.Report do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
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
