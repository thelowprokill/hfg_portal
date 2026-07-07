defmodule Budget.AccountBalances do
  import Ecto.Query

  @topic "budget:account_balances"
  @schema Budget.AccountBalances.AccountBalance
  @updated [:account_balance, :updated]
  @created [:account_balance, :created]
  @deleted [:account_balance, :deleted]

  use HfgPortal.Helpers.DefaultCrud,
    schema: @schema,
    topic: @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def get_by(account_id, year, month) do
    @schema
    |> where([b], b.account_id == ^account_id and b.year == ^year and b.month == ^month)
    |> Repo.one()
  end

  def get_or_new(account_id, year, month) do
    get_by(account_id, year, month) ||
      %@schema{
        account_id: account_id,
        year: year,
        month: month,
        balance: Decimal.new(0)
      }
  end

  def map_for_month(year, month) do
    @schema
    |> where([b], b.year == ^year and b.month == ^month)
    |> select([b], {b.account_id, b.balance})
    |> Repo.all()
    |> Map.new()
  end

  def upsert(account_id, year, month, attrs) do
    get_or_new(account_id, year, month) |> create_or_update(attrs)
  end
end
