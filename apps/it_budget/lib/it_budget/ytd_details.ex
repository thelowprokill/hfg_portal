defmodule ItBudget.YtdDetails do
  import Ecto.Query
  import BnwPortal.Helpers.Utility

  alias ItBudget.{
    Accounts.Account,
    Accounts.AccountSub,
    Budgets.Budget,
    Budgets.BudgetAccount,
    YtdDetail.YtdDetail,
    YtdDetail.TkYtd,
    Budgets,
    Accounts,
    Repo
  }

  @topic "it_budget:ytd_detail"
  @schema ItBudget.YtdDetail.YtdDetail
  @updated [:ytd_detail, :updated]
  @created [:ytd_detail, :created]
  @deleted [:ytd_detail, :deleted]

  def subscribe(),     do: Phoenix.PubSub.subscribe(BnwPortal.PubSub,   @topic)
  def subscribe(id),   do: Phoenix.PubSub.subscribe(BnwPortal.PubSub,   "#{@topic}:#{id}")
  def unsubscribe(),   do: Phoenix.PubSub.unsubscribe(BnwPortal.PubSub, @topic)
  def unsubscribe(id), do: Phoenix.PubSub.unsubscribe(BnwPortal.PubSub, "#{@topic}:#{id}")
  defp notify_subscribers({:ok, nil}, event) do
    Phoenix.PubSub.broadcast(BnwPortal.PubSub, @topic, {event, nil})
    Phoenix.PubSub.broadcast(BnwPortal.PubSub, "#{@topic}:#{nil}", {event, nil})
    {:ok, nil}
  end
  defp notify_subscribers({:ok, result}, event) do
    Phoenix.PubSub.broadcast(BnwPortal.PubSub, @topic, {event, result})
    Phoenix.PubSub.broadcast(BnwPortal.PubSub, "#{@topic}:#{result.id}", {event, result})
    {:ok, result}
  end
  defp notify_subscribers({:error, reason}, _event), do: {:error, reason}


  def transfer_ytd(budget_id, period) do
    cur_time = 
      DateTime.utc_now()
      |> DateTime.truncate(:second)
      |> DateTime.to_naive()

    month = period |> case do
      val when val <= 2 -> val + 10
      val -> val - 2
    end

    year = 
      Budgets.get(budget_id) |> Map.get(:year)
      |> case do
        val when period <= 2 -> val - 1
        val -> val
      end

    accounts = Accounts.list()

    labor = 
      BudgetAccount
      |> join(:inner, [ba],     as in AccountSub, on: as.id == ba.account_sub_id)
      |> join(:inner, [ba, as], a  in Account,    on: a.id  == as.account_id)
      |> where([ba, _, _], ba.budget_id == ^budget_id)
      |> where([_, _, a],  a.name == "labor")
      |> select([ba, as, a], %{
        budget_id:        ^budget_id,
        account_id:       a.id,
        amount:           field(ba, ^("month_#{period}" |> String.to_atom())),
        trx_date:         ^(Date.new!(year, month, 1)),
        period:           ^period,
        description:      ^"Labor for Period #{period}",
        detail_reference: nil,
        inserted_at:      ^cur_time,
        updated_at:       ^cur_time,
      })
      |> limit(1)
      |> Repo.one()

    multi = Ecto.Multi.new() |> Ecto.Multi.delete_all(:delete_all, from(t in YtdDetail, where: t.budget_id == ^budget_id and t.period == ^period))

    TkYtd
    |> where([t], t.gl_account == 6210500)
    |> where([t], fragment("month(?)", t.trx_date) == ^month)
    |> where([t], fragment("year(?)",  t.trx_date) == ^year)
    |> Repo.all()
    |> Enum.map(fn x -> 
      acc = Enum.find(accounts, %{id: nil}, fn a -> a.code == String.slice(x.reference, 3, 3) end) |> Map.get(:id)
      %{
        budget_id:        budget_id,
        account_id:       acc,
        amount:           x.trx_amount,
        trx_date:         x.trx_date,
        period:           period,
        description:      x.reference,
        detail_reference: x.detail_reference,
        inserted_at:      cur_time,
        updated_at:       cur_time,
      }
    end)
    |> fn x -> [labor] ++ x end.()
    |> Enum.chunk_every(128)
    |> Enum.with_index()
    |> Enum.reduce(multi, fn({x, i}, acc) ->
      acc |> Ecto.Multi.insert_all({:insert_all, i}, YtdDetail, x)
    end)
    |> Repo.transaction(timeout: 300_000)
    |> case do
      {:ok, _} -> 
        notify_subscribers({:ok, nil}, [:ytd_detail, :transfered])
      {:error, _} -> :error
      _ -> :error
    end
  end

  defp search_stack(query, search_stack) when is_list(search_stack) do
    Enum.reduce(search_stack, query, fn(search, query) ->
      cond do
        search.field == :budget  -> query |> where([yd, a, b], like(b.year, ^"%#{search.val}%") or ^search.val == "")
        search.field == :account -> query |> where([yd, a, b], like(a.name, ^"%#{search.val}%") or ^search.val == "" or (is_nil(yd.account_id) and like("No Account", ^"%#{search.val}%")))
        search.field in @schema.__schema__(:fields) -> query |> where([r], like(field(r, ^search.field), ^"%#{search.val}%") or ^search.val == "")
        true -> query
      end
    end)
  end
  defp search_stack(query, nil), do: query

  defp sort_stack(query, sort_stack) when is_list(sort_stack) do
    Enum.reduce(sort_stack, query, fn(sort, query) ->
      cond do
        sort.field == :budget  -> query |> order_by([yd, a, b], [{^sort.order, b.year}])
        sort.field == :account -> query |> order_by([yd, a, b], [{^sort.order, a.name}])
        sort.field in @schema.__schema__(:fields) -> query |> order_by([{^sort.order, ^sort.field}])
        true -> query
      end
    end)
  end
  defp sort_stack(query, nil), do: query

  def filter_active(query, active) when not is_nil(active), do: query |> where(active: ^active)
  def filter_active(query, _active), do: query

  def list(opts \\ %{}) do
    @schema
    |> join(:left, [yd],    a in Account, on: a.id == yd.account_id)
    |> join(:left, [yd, a], b in Budget,  on: b.id == yd.budget_id)
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> Repo.all()
    |> bnw_preload(Map.get(opts, :preload, []))
  end
  def preload(val, opts \\ %{}), do: bnw_preload(val, Map.get(opts, :preload, []))

  def create_or_update(%@schema{} = item, attrs \\ %{}) do
    new_item = is_nil(item.id)
    item
    |> change(attrs)
    |> Repo.insert_or_update()
    |> notify_subscribers(if new_item, do: @created, else: @updated)
  end

  def get(id), do: Repo.get(@schema, id)
  def new(), do: %@schema{}
  def new_changeset(attrs \\ %{}), do: new() |> change(attrs)
  def change(%@schema{} = item, attrs \\ %{}), do: @schema.changeset(item, attrs)
  def delete(%@schema{} = item), do: item |> Repo.delete() |> notify_subscribers(@deleted)
  def delete(id), do: get(id) |> delete()

  def activate(%@schema{} = item),   do: item |> change(%{active: true})  |> Repo.update() |> notify_subscribers(@updated)
  def activate(id), do: get(id) |> activate()
  def deactivate(%@schema{} = item), do: item |> change(%{active: false}) |> Repo.update() |> notify_subscribers(@updated)
  def deactivate(id), do: get(id) |> deactivate()
end
