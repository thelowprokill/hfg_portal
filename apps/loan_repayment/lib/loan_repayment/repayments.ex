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

  def list(opts) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> paginate(opts)
    |> filter_loan(Map.get(opts, :loan_id))
    |> order_by([r], [desc: r.paid_amount_tot, desc: r.id])
    |> Repo.all()
    |> preload_associations(opts)
  end
end
