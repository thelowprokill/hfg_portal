defmodule ItBudget.YtdDetail.YtdDetail do
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

  schema "ytd_detail" do
    belongs_to :budget,      ItBudget.Budgets.Budget
    belongs_to :account,     ItBudget.Accounts.Account
    field :amount,           :decimal
    field :trx_date,         :date
    field :period,           :integer
    field :description,      :string
    field :detail_reference, :string

    timestamps()
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [
      :budget_id,  
      :account_id, 
      :amount,       
      :trx_date,     
      :period,       
      :description,  
      :detail_reference,
    ])
  end
end


