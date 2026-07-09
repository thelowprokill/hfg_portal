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

  def get_by_date(account_id, date) do
    @schema
    |> where([b], b.account_id == ^account_id and b.date == ^date)
    |> Repo.one()
  end

  def get_or_new(account_id, date) do
    get_by_date(account_id, date) ||
      %@schema{account_id: account_id, date: date, balance: Decimal.new(0)}
  end

  @doc """
  Returns a map of account_id => balance reflecting each account's most
  recently recorded balance on or before the end of `year`/`month`. Carries
  forward the last known value if nothing has been recorded yet this month.
  """
  def map_for_month(year, month) do
    end_date = Date.end_of_month(Date.new!(year, month, 1))

    latest =
      from(b in @schema,
        where: b.date <= ^end_date,
        group_by: b.account_id,
        select: %{account_id: b.account_id, date: max(b.date)}
      )

    from(b in @schema,
      join: l in subquery(latest),
      on: b.account_id == l.account_id and b.date == l.date,
      select: {b.account_id, b.balance}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns the most recent balance date on file across all accounts, on or
  before the end of `year`/`month`, or nil if nothing has been recorded yet.
  """
  def latest_date_for_month(year, month) do
    end_date = Date.end_of_month(Date.new!(year, month, 1))

    @schema
    |> where([b], b.date <= ^end_date)
    |> select([b], max(b.date))
    |> Repo.one()
  end

  @doc """
  Upserts the balance for `account_id` on `attrs[:date]` (defaults to today).
  """
  def upsert(account_id, attrs) do
    date = Map.get(attrs, :date, Date.utc_today())
    get_or_new(account_id, date) |> create_or_update(Map.put(attrs, :date, date))
  end
end
