defmodule Budget.Transactions do
  import Ecto.Query

  @topic   "budget:transactions"
  @schema  Budget.Transactions.Transaction
  @updated [:transaction, :updated]
  @created [:transaction, :created]
  @deleted [:transaction, :deleted]

  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  # Override to sync bucket balance after every write
  def create_or_update(%Budget.Transactions.Transaction{} = item, attrs \\ %{}) do
    new_item = is_nil(item.id)

    result =
      item
      |> change(attrs)
      |> Repo.insert_or_update()
      |> notify_subscribers(if new_item, do: @created, else: @updated)

    with {:ok, transaction} <- result, do: sync_bucket_balance(transaction.bucket_id)
    result
  end

  def delete(%Budget.Transactions.Transaction{} = item) do
    bucket_id = item.bucket_id
    result    = item |> Repo.delete() |> notify_subscribers(@deleted)
    with {:ok, _} <- result, do: sync_bucket_balance(bucket_id)
    result
  end

  def delete(id), do: get(id) |> delete()

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> Repo.all()
    |> preload(opts)
  end

  def new_changeset(attrs \\ %{}) do
    %@schema{transaction_date: Date.utc_today()}
    |> change(Map.put_new(attrs, :transaction_date, Date.utc_today()))
  end

  def list_for_bucket(bucket_id) do
    @schema
    |> where([t], t.bucket_id == ^bucket_id)
    |> order_by([t], desc: t.transaction_date)
    |> Repo.all()
  end

  def list_for_month(bucket_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date   = Date.end_of_month(start_date)

    @schema
    |> where([t], t.bucket_id == ^bucket_id)
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> order_by([t], desc: t.transaction_date)
    |> Repo.all()
  end

  def monthly_expense_total(bucket_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date   = Date.end_of_month(start_date)

    @schema
    |> where([t], t.bucket_id == ^bucket_id and t.type == "expense")
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> select([t], sum(t.amount))
    |> Repo.one()
    |> Kernel.||(Decimal.new(0))
  end

  def sinking_fund_deposit_this_month?(bucket_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date   = Date.end_of_month(start_date)

    @schema
    |> where([t], t.bucket_id == ^bucket_id and t.type == "sinking_fund_deposit")
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> Repo.exists?()
  end

  def balance_as_of_month(bucket_id, year, month) do
    end_date = Date.end_of_month(Date.new!(year, month, 1))

    @schema
    |> where([t], t.bucket_id == ^bucket_id and t.transaction_date <= ^end_date)
    |> select([t], fragment(
      "COALESCE(SUM(CASE WHEN type IN ('contribution','sinking_fund_deposit') THEN amount WHEN type = 'expense' THEN -amount ELSE 0 END), 0)"
    ))
    |> Repo.one()
    |> Kernel.||(Decimal.new(0))
  end

  def monthly_deposit_total(bucket_id, year, month) do
    start_date = Date.new!(year, month, 1)
    end_date   = Date.end_of_month(start_date)

    @schema
    |> where([t], t.bucket_id == ^bucket_id and t.type in ["contribution", "sinking_fund_deposit"])
    |> where([t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
    |> select([t], sum(t.amount))
    |> Repo.one()
    |> Kernel.||(Decimal.new(0))
  end

  def list_filtered(opts \\ %{}) do
    @schema
    |> then(fn q ->
      case Map.get(opts, :bucket_id) do
        nil -> q
        id  -> where(q, [t], t.bucket_id == ^id)
      end
    end)
    |> then(fn q ->
      case {Map.get(opts, :year), Map.get(opts, :month)} do
        {y, m} when not is_nil(y) and not is_nil(m) ->
          start_date = Date.new!(y, m, 1)
          end_date   = Date.end_of_month(start_date)
          where(q, [t], t.transaction_date >= ^start_date and t.transaction_date <= ^end_date)
        _ -> q
      end
    end)
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> order_by([t], desc: t.transaction_date)
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> Repo.all()
  end

  defp sync_bucket_balance(bucket_id) do
    balance =
      @schema
      |> where([t], t.bucket_id == ^bucket_id)
      |> select([t], fragment(
        "COALESCE(SUM(CASE WHEN type IN ('contribution','sinking_fund_deposit') THEN amount WHEN type = 'expense' THEN -amount ELSE 0 END), 0)"
      ))
      |> Repo.one()
      |> Kernel.||(Decimal.new(0))

    Budget.Buckets.Bucket
    |> where([b], b.id == ^bucket_id)
    |> Repo.update_all(set: [balance: balance])
  end
end
