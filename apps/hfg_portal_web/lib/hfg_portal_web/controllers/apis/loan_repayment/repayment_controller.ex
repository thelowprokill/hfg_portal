defmodule HfgPortalWeb.Apis.LoanRepayment.RepaymentController do
  use HfgPortalWeb, :controller

  @routes [
    %{name: "repayments", method: "GET",    function: &__MODULE__.get_repayments/2,   role: :view,  description: "List repayments, optionally filtered by loan_id"},
    %{name: "repayment",  method: "GET",    function: &__MODULE__.get_repayment/2,    role: :view,  description: "Get a repayment by id"},
    %{name: "repayment",  method: "PUT",    function: &__MODULE__.put_repayment/2,    role: :edit,  description: "Add or update a repayment"},
    %{name: "repayment",  method: "DELETE", function: &__MODULE__.delete_repayment/2, role: :admin, description: "Delete a repayment"},
  ]

  alias LoanRepayment.Repayments
  alias HfgPortalWeb.Apis.LoanRepayment.AuthController

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

  def get_repayments(%{query_params: query_params} = conn, _params) do
    loan_id =
      case Map.get(query_params, "loan_id") do
        nil -> nil
        id  -> String.to_integer(id)
      end

    repayments =
      Repayments.list(%{
        page:     Map.get(query_params, "page"),
        per_page: Map.get(query_params, "per_page"),
        loan_id:  loan_id,
      })
      |> Enum.map(&serialize_repayment/1)

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      data: repayments,
    })
  end

  def get_repayment(%{query_params: %{"id" => id}} = conn, _params) do
    repayment =
      id |> String.to_integer()
      |> Repayments.get()
      |> serialize_repayment()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      data: repayment,
    })
  end

  def put_repayment(%{query_params: %{"id" => id} = params} = conn, _params) do
    update_params = build_repayment_params(params)

    id |> String.to_integer()
    |> Repayments.get()
    |> Repayments.create_or_update(update_params)
    |> respond_with_repayment(conn)
  end

  def put_repayment(%{query_params: params} = conn, _params) do
    update_params = build_repayment_params(params)

    Repayments.new()
    |> Repayments.create_or_update(update_params)
    |> respond_with_repayment(conn)
  end

  def delete_repayment(%{query_params: %{"id" => id}} = conn, _params) do
    id |> String.to_integer()
    |> Repayments.delete()

    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      data: nil,
    })
  end

  defp build_repayment_params(params) do
    %{
      loan_id:          Map.get(params, "loan_id"),
      paid_amount:      Map.get(params, "paid_amount"),
      last_paid_amount: Map.get(params, "last_paid_amount"),
      loan_amount:      Map.get(params, "loan_amount"),
    }
    |> Enum.reject(fn {_k, v} -> v == "" or v == nil end)
    |> Enum.into(%{})
  end

  defp respond_with_repayment({:ok, repayment}, conn) do
    conn
    |> put_status(:ok)
    |> json(%{
      response: :ok,
      date: DateTime.utc_now(),
      data: serialize_repayment(repayment),
    })
  end
  defp respond_with_repayment({:error, error}, conn) do
    conn
    |> put_status(:ok)
    |> json(%{
      response: :error,
      date: DateTime.utc_now(),
      data: nil,
      error: error,
    })
  end

  defp serialize_repayment(repayment) do
    %{
      id:                repayment.id,
      loan_id:           repayment.loan_id,
      paid_amount:       repayment.paid_amount,
      paid_amount_tot:   repayment.paid_amount_tot,
      remaining_balance: repayment.remaining_balance,
    }
  end
end
