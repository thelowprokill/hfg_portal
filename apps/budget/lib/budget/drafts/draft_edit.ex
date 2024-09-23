defmodule Budget.Drafts.DraftEdit do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.CompanyBudget,
    Companies.DraftType,
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "drafts" do
    field :name,                   :string
    field :year,                   :integer, default: DateTime.utc_now().year() + 1
    field :start_date,             :date
    field :starting_month,         :integer, virtual: true
    belongs_to :company_budget,      CompanyBudget
    belongs_to :draft_type,          DraftType
    belongs_to :previous_year_draft, __MODULE__

    timestamps()
  end

  def changeset(draft, attrs \\ %{}) do
    draft
    |> cast(attrs, [
      :name,
      :year,
      :start_date,
      :starting_month,
      :company_budget_id,
      :draft_type_id,
      :previous_year_draft_id
    ])
    |> set_start_date()
    |> validate_required([:name, :year, :start_date])
    |> unique_constraint(:name, name: :drafts_unique_index)
  end

  defp set_start_date(changeset) do
    start_date     = get_field(changeset, :start_date)
    starting_month = get_field(changeset, :starting_month)
    year           = get_field(changeset, :year)

    cond do
      is_nil(start_date) && starting_month && year -> 
        put_change(changeset, :start_date, Date.new!(year, starting_month, 1))
      true -> changeset
    end
  end

end
