defmodule Budget.Reports.ReportAdmin do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "bnw_portal_budget"
  prefix = case Application.compile_env(:budget, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "report_admin" do
    field :username, :string
    field :password, :string
    field :active,   :boolean, default: true

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :username,
      :password,
      :active,  
    ])
    |> validate_required([:username, :password])
  end
end



