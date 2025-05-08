defmodule LoanRepayment.Repayments do
  @topic "repayment_repayment:repayments"
  @schema LoanRepayment.Loans.Repayment
  @updated [:repayment, :updated]
  @created [:repayment, :created]
  @deleted [:repayment, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def repayment_query() do
    @schema
    |> group_by([r], [r.loan_id])
    |> select([r], %{loan_id: r.loan_id, paid_amount_tot: max(r.paid_amount_tot)})
  end

  defp filter_loan(query, loan_id) when not is_nil(loan_id), do: query |> where(loan_id: ^loan_id)
  defp filter_loan(query, _loan_id), do: query

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_loan(Map.get(opts, :loan_id))
    |> order_by([r], [desc: r.paid_amount_tot, desc: r.id])
    |> Repo.all()
    |> bnw_preload(Map.get(opts, :preload, []))
  end

  #import Ecto.Query
  #import HfgPortal.Helpers.Utility

  #alias LoanRepayment.Repo

  #def subscribe(),     do: Phoenix.PubSub.subscribe(HfgPortal.PubSub,   @topic)
  #def subscribe(id),   do: Phoenix.PubSub.subscribe(HfgPortal.PubSub,   "#{@topic}:#{id}")
  #def unsubscribe(),   do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, @topic)
  #def unsubscribe(id), do: Phoenix.PubSub.unsubscribe(HfgPortal.PubSub, "#{@topic}:#{id}")
  #defp notify_subscribers({:ok, result}, event) do
  #  Phoenix.PubSub.broadcast(HfgPortal.PubSub, @topic, {event, result})
  #  Phoenix.PubSub.broadcast(HfgPortal.PubSub, "#{@topic}:#{result.id}", {event, result})
  #  {:ok, result}
  #end
  #defp notify_subscribers({:error, reason}, _event), do: {:error, reason}


  #defp search_stack(query, search_stack) when is_list(search_stack) do
  #  Enum.reduce(search_stack, query, fn(search, query) ->
  #    cond do
  #      search.field in @schema.__schema__(:fields) -> query |> where([r], like(field(r, ^search.field), ^"%#{search.val}%") or ^search.val == "")
  #      true -> query
  #    end
  #  end)
  #end
  #defp search_stack(query, nil), do: query

  #defp sort_stack(query, sort_stack) when is_list(sort_stack) do
  #  Enum.reduce(sort_stack, query, fn(sort, query) ->
  #    cond do
  #      sort.field in @schema.__schema__(:fields) -> query |> order_by([{^sort.order, ^sort.field}])
  #      true -> query
  #    end
  #  end)
  #end
  #defp sort_stack(query, nil), do: query

  ##defp filter_user(query, user_id) when not is_nil(user_id), do: query |> where(user_id: ^user_id)
  ##defp filter_user(query, _user_id), do: query

  ##defp filter_dates(query, dates) when not is_nil(dates) do
  ##  query
  ##  |> where([c], c.monday in ^dates)
  ##end
  ##defp filter_dates(query, _dates), do: query

  #def list(opts \\ %{}) do
  #  @schema
  #  |> search_stack(Map.get(opts, :search_stack))
  #  |> sort_stack(Map.get(opts, :sort_stack))
  #  |> bnw_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
  #  |> filter_loan(Map.get(opts, :loan_id))
  #  |> order_by([r], [desc: r.paid_amount_tot, desc: r.id])
  #  |> Repo.all()
  #  |> bnw_preload(Map.get(opts, :preload, []))
  #end
  #def preload(val, opts \\ %{}), do: bnw_preload(val, Map.get(opts, :preload, []))

  #def create_or_update(%@schema{} = item, attrs \\ %{}) do
  #  new_item = is_nil(item.id)
  #  item
  #  |> change(attrs)
  #  |> Repo.insert_or_update()
  #  |> notify_subscribers(if new_item, do: @created, else: @updated)
  #end

  #def get(id), do: Repo.get(@schema, id)
  #def new(), do: %@schema{}
  #def new_changeset(attrs \\ %{}), do: new() |> change(attrs)
  #def change(%@schema{} = item, attrs \\ %{}), do: @schema.changeset(item, attrs)
  #def delete(%@schema{} = item), do: item |> Repo.delete() |> notify_subscribers(@deleted)
  #def delete(id), do: get(id) |> delete()

  #def activate(%@schema{} = item),   do: item |> change(%{active: true})  |> Repo.update() |> notify_subscribers(@updated)
  #def activate(id), do: get(id) |> activate()
  #def deactivate(%@schema{} = item), do: item |> change(%{active: false}) |> Repo.update() |> notify_subscribers(@updated)
  #def deactivate(id), do: get(id) |> deactivate()
end
