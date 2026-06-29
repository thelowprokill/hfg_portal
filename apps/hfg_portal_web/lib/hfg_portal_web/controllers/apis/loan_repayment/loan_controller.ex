defmodule HfgPortalWeb.Apis.LoanRepayment.LoanController do
  use HfgPortalWeb, :controller

  @routes [
    %{name: "loans", method: "GET",    function: &__MODULE__.get_loans/2,   role: :view,  description: "List all loans"},
    %{name: "loan",  method: "GET",    function: &__MODULE__.get_loan/2,    role: :view,  description: "Get a loan by id"},
    %{name: "loan",  method: "PUT",    function: &__MODULE__.put_loan/2,    role: :admin, description: "Add or update a loan"},
    %{name: "loan",  method: "DELETE", function: &__MODULE__.delete_loan/2, role: :admin, description: "Delete a loan"},
  ]

  import HfgPortalWeb.Apis.ApiHelpers

  alias LoanRepayment.{Loans, Repayments}
  alias HfgPortalWeb.Apis.LoanRepayment.AuthController

  @preload [repayment: Repayments.repayment_query()]

  def call(%{method: method, query_params: %{"route" => route}} = conn, params) do
    Enum.find(@routes, &(&1.name == route && &1.method == method))
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Route not found"})
      %{function: fun} = route_config ->
        if AuthController.authorized?(conn, route_config),
          do:   fun.(conn, params),
          else: conn |> put_status(401) |> json(%{error: "Unauthorized"})
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Route not found"})
    end
  end

  def get_loans(%{query_params: query_params} = conn, _params) do
    with {:ok, search_stack} <- parse_search_stack(Map.get(query_params, "search_stack")),
         {:ok, sort_stack}   <- parse_sort_stack(Map.get(query_params, "sort_stack")) do
      loans =
        Loans.list(%{
          page:         Map.get(query_params, "page"),
          per_page:     Map.get(query_params, "per_page"),
          search_stack: search_stack,
          sort_stack:   sort_stack,
          preload:      @preload,
        })
        |> Enum.map(&serialize_loan/1)

      conn
      |> put_status(:ok)
      |> json(%{
        response: :ok,
        date: DateTime.utc_now(),
        data: loans,
      })
    else
      {:error, msg} -> conn |> put_status(400) |> json(%{error: msg})
    end
  end

  def get_loan(%{query_params: %{"id" => id}} = conn, _params) do
    loan =
      id |> String.to_integer()
      |> Loans.get()
      |> Loans.preload(%{preload: @preload})
      |> serialize_loan()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      data: loan,
    })
  end

  def put_loan(%{query_params: %{"id" => id} = params} = conn, _params) do
    update_params = build_loan_params(params)

    id |> String.to_integer()
    |> Loans.get()
    |> Loans.create_or_update(update_params)
    |> respond_with_loan(conn)
  end

  def put_loan(%{query_params: params} = conn, _params) do
    update_params = build_loan_params(params)

    Loans.new()
    |> Loans.create_or_update(update_params)
    |> respond_with_loan(conn)
  end

  def delete_loan(%{query_params: %{"id" => id}} = conn, _params) do
    id |> String.to_integer()
    |> Loans.delete()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      data: nil,
    })
  end

  defp build_loan_params(params) do
    %{
      paid_to:     Map.get(params, "paid_to"),
      for:         Map.get(params, "for"),
      description: Map.get(params, "description"),
      amount:      Map.get(params, "amount"),
      active:      Map.get(params, "active"),
    }
    |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
    |> Enum.into(%{})
  end

  defp respond_with_loan({:ok, loan}, conn) do
    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      data: serialize_loan(loan),
    })
  end
  defp respond_with_loan({:error, error}, conn) do
    conn
    |> put_status(:ok)
    |> json(%{
      response: :error,
      date: DateTime.utc_now(),
      data: nil,
      error: error,
    })
  end

  defp serialize_loan(loan) do
    repayment = Map.get(loan, :repayment)
    %{
      id:                loan.id,
      paid_to:           loan.paid_to,
      for:               loan.for,
      description:       loan.description,
      amount:            loan.amount,
      active:            loan.active,
      paid_amount_tot:   (if repayment, do: Map.get(repayment, :paid_amount_tot)),
      remaining_balance: Decimal.sub(loan.amount, if(repayment, do: Map.get(repayment, :paid_amount_tot), else: Decimal.new(0))),
    }
  end
end
