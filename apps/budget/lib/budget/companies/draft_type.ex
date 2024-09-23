defmodule Budget.Companies.DraftType do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.Company,
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "draft_types" do
    field :name,                :string
    field :order_number,        :integer
    field :instructions,        :string
    field :show_planning,       :boolean, default: true
    field :show_monthly_inputs, :boolean, default: true

    belongs_to :company, Company

    timestamps()
  end

  def changeset(draft_type, attrs \\ %{}) do
    draft_type
    |> cast(attrs, [
      :name, 
      :order_number, 
      :instructions, 
      :show_planning,
      :show_monthly_inputs,
      :company_id
    ])
    |> validate_required([:name, :order_number])
    |> unique_constraint(:name, name: :draft_type_unique_index)
    |> unique_constraint(:name, name: :draft_types_company_id_order_number_index)
  end
end
