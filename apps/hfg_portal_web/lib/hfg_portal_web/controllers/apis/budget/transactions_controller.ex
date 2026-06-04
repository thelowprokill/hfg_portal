defmodule HfgPortalWeb.Apis.Budget.TransactionsController do
  use HfgPortalWeb, :controller

  alias Budget.Transactions

  @routes [
    %{name: "transactions", method: "GET",    function: &__MODULE__.list_transactions/2,  description: "List transactions (optional: bucket_id, year, month, page, per_page)"},
    %{name: "transaction",  method: "GET",    function: &__MODULE__.get_transaction/2,    description: "Get a transaction by id"},
    %{name: "transaction",  method: "PUT",    function: &__MODULE__.put_transaction/2,    description: "Create or update a transaction"},
    %{name: "transaction",  method: "DELETE", function: &__MODULE__.delete_transaction/2, description: "Delete a transaction"},
  ]

  def call(%{method: method, query_params: %{"route" => route}} = conn, params) do
    Enum.find(@routes, &(&1.name == route && &1.method == method))
    |> case do
      nil            -> conn |> put_status(:not_found) |> json(%{error: "Route not found"})
      %{function: f} -> f.(conn, params)
    end
  end

  def list_transactions(%{params: params} = conn, _params) do
    %{id: user_id} = conn.assigns.current_api_user

    opts = %{
      bucket_id: parse_int(Map.get(params, "bucket_id")),
      year:      parse_int(Map.get(params, "year")),
      month:     parse_int(Map.get(params, "month")),
      page:      parse_int(Map.get(params, "page", "0")),
      per_page:  parse_int(Map.get(params, "per_page", "50")),
    }

    transactions = Transactions.list_for_user(user_id, opts) |> Enum.map(&serialize/1)
    conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: transactions})
  end

  def get_transaction(%{query_params: %{"id" => id}} = conn, _params) do
    transaction = id |> String.to_integer() |> Transactions.get()
    conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: serialize(transaction)})
  end

  def put_transaction(%{params: params} = conn, _params) do
    attrs = %{
      bucket_id:            parse_int(Map.get(params, "bucket_id")),
      scheduled_expense_id: parse_int(Map.get(params, "scheduled_expense_id")),
      created_by_id:        conn.assigns.current_api_user.id,
      amount:               Map.get(params, "amount"),
      description:          Map.get(params, "description"),
      transaction_date:     parse_date(Map.get(params, "transaction_date")),
      type:                 Map.get(params, "type"),
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()

    base =
      case Map.get(params, "id") do
        nil -> Transactions.new()
        id  -> id |> String.to_integer() |> Transactions.get()
      end

    base
    |> Transactions.create_or_update(attrs)
    |> case do
      {:ok, t}      -> conn |> put_status(:ok) |> json(%{response: :ok,    date: DateTime.utc_now(), data: serialize(t)})
      {:error, cs}  -> conn |> put_status(:ok) |> json(%{response: :error, date: DateTime.utc_now(), errors: format_errors(cs)})
    end
  end

  def delete_transaction(%{query_params: %{"id" => id}} = conn, _params) do
    id |> String.to_integer() |> Transactions.delete()
    conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: nil})
  end

  defp serialize(nil), do: nil
  defp serialize(t) do
    %{
      id:                   t.id,
      bucket_id:            t.bucket_id,
      scheduled_expense_id: t.scheduled_expense_id,
      created_by_id:        t.created_by_id,
      amount:               to_string(t.amount),
      description:          t.description,
      type:                 t.type,
      transaction_date:     Date.to_iso8601(t.transaction_date),
    }
  end

  defp parse_int(nil), do: nil
  defp parse_int(s) when is_binary(s), do: String.to_integer(s)
  defp parse_int(i) when is_integer(i), do: i

  defp parse_date(nil), do: nil
  defp parse_date(s), do: Date.from_iso8601!(s)

  defp format_errors(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
  end
end
