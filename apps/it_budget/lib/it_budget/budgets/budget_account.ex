defmodule ItBudget.Budgets.BudgetAccount do
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

  schema "budget_accounts" do
    belongs_to :budget,      ItBudget.Budgets.Budget
    belongs_to :account_sub, ItBudget.Accounts.AccountSub
    field :account_id,       :integer, virtual: true
    field :all_months,       :decimal, virtual: true
    field :use_all_months,   :boolean, virtual: true, default: false
    field :month_0,          :decimal
    field :month_1,          :decimal
    field :month_2,          :decimal
    field :month_3,          :decimal
    field :month_4,          :decimal
    field :month_5,          :decimal
    field :month_6,          :decimal
    field :month_7,          :decimal
    field :month_8,          :decimal
    field :month_9,          :decimal
    field :month_10,         :decimal
    field :month_11,         :decimal

    field :description,      :string
    field :active,           :boolean, default: true
    belongs_to :user,        BnwPortal.Accounts.User

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :budget_id,
      :account_sub_id,
      :account_id,
      :all_months,
      :use_all_months,
      :month_0,
      :month_1,
      :month_2,
      :month_3,
      :month_4,
      :month_5,
      :month_6,
      :month_7,
      :month_8,
      :month_9,
      :month_10,
      :month_11,

      :description,
      :active,
      :user_id,
    ])
    |> calculate_months()
  end

  defp calculate_months(changeset) do
    all_months     = get_field(changeset, :all_months)
    use_all_months = get_field(changeset, :use_all_months)

    cond do 
      use_all_months ->
        changeset
        |> put_change(:month_0,  all_months)
        |> put_change(:month_1,  all_months)
        |> put_change(:month_2,  all_months)
        |> put_change(:month_3,  all_months)
        |> put_change(:month_4,  all_months)
        |> put_change(:month_5,  all_months)
        |> put_change(:month_6,  all_months)
        |> put_change(:month_7,  all_months)
        |> put_change(:month_8,  all_months)
        |> put_change(:month_9,  all_months)
        |> put_change(:month_10, all_months)
        |> put_change(:month_11, all_months)
      true ->
        changeset
        |> put_change(:all_months, get_field(changeset, :month_0))
    end
  end
end


