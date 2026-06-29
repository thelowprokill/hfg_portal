defmodule HfgPortalWeb.Apis.Budget.ScheduledExpensesController do
  use HfgPortalWeb, :controller

  import HfgPortalWeb.Apis.ApiHelpers

  alias Budget.ScheduledExpenses
  alias HfgPortalWeb.Apis.Budget.AuthController

  @routes [
    %{name: "scheduled_expenses", method: "GET",    function: &__MODULE__.get_scheduled_expenses/2,   role: :view,  description: "List scheduled expenses for the current user"},
    %{name: "scheduled_expense",  method: "GET",    function: &__MODULE__.get_scheduled_expense/2,    role: :view,  description: "Get a scheduled expense by id"},
    %{name: "scheduled_expense",  method: "PUT",    function: &__MODULE__.put_scheduled_expense/2,    role: :admin, description: "Create or update a scheduled expense"},
    %{name: "scheduled_expense",  method: "DELETE", function: &__MODULE__.delete_scheduled_expense/2, role: :admin, description: "Delete a scheduled expense"},
    %{name: "run_scheduled",      method: "PUT",    function: &__MODULE__.run_scheduled/2,            role: :admin, description: "Process due scheduled expenses and sinking fund contributions"},
  ]

  @preload []

  def call(%{method: method, query_params: %{"route" => route}} = conn, params) do
    Enum.find(@routes, &(&1.name == route && &1.method == method))
    |> case do
      nil                      -> conn |> put_status(:not_found) |> json(%{error: "Route not found"})
      %{function: f} = route_config ->
        if AuthController.authorized?(conn, route_config),
          do:   f.(conn, params),
          else: conn |> put_status(401) |> json(%{error: "Unauthorized"})
    end
  end

  def get_scheduled_expenses(%{query_params: query_params} = conn, _params) do
    #%{id: user_id} = conn.assigns.current_api_user
    #expenses = ScheduledExpenses.list_for_user(user_id) |> Enum.map(&serialize/1)
    #conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: expenses})
    with {:ok, search_stack} <- parse_search_stack(Map.get(query_params, "search_stack")),
         {:ok, sort_stack}   <- parse_sort_stack(Map.get(query_params, "sort_stack")) do
      scheduled_expenses =
        ScheduledExpenses.list(%{
          page:         Map.get(query_params, "page"),
          per_page:     Map.get(query_params, "per_page"),
          bucket_id:    Map.get(query_params, "bucket_id"),
          search_stack: search_stack,
          sort_stack:   sort_stack,
          preload:      @preload,
        })
      conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: scheduled_expenses |> Enum.map(&serialize(&1))})
    else
      {:error, msg} -> conn |> put_status(400) |> json(%{error: msg})
    end
  end
  #def get_scheduled_expenses(conn, _params) do
  #  %{id: user_id} = conn.assigns.current_api_user
  #  expenses = ScheduledExpenses.list_for_user(user_id) |> Enum.map(&serialize/1)
  #  conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: expenses})
  #end

  def get_scheduled_expense(%{query_params: %{"id" => id}} = conn, _params) do
    expense = id |> String.to_integer() |> ScheduledExpenses.get() |> ScheduledExpenses.preload(%{preload: @preload})
    conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: serialize(expense)})
  end

  def put_scheduled_expense(%{params: params} = conn, _params) do
    attrs = %{
      bucket_id:     parse_int(Map.get(params, "bucket_id")),
      amount:        Map.get(params, "amount"),
      description:   Map.get(params, "description"),
      frequency:     Map.get(params, "frequency"),
      day_of_month:  parse_int(Map.get(params, "day_of_month")),
      day_of_week:   parse_int(Map.get(params, "day_of_week")),
      month_of_year: parse_int(Map.get(params, "month_of_year")),
      next_due_date: parse_date(Map.get(params, "next_due_date")),
      active:        Map.get(params, "active"),
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()

    base =
      case Map.get(params, "id") do
        nil -> ScheduledExpenses.new() |> ScheduledExpenses.preload(%{preload: @preload})
        id  -> id |> String.to_integer() |> ScheduledExpenses.get() |> ScheduledExpenses.preload(%{preload: @preload})
      end

    base
    |> ScheduledExpenses.create_or_update(attrs)
    |> case do
      {:ok, se}    -> conn |> put_status(:ok) |> json(%{response: :ok,    date: DateTime.utc_now(), data: serialize(se)})
      {:error, cs} -> conn |> put_status(:ok) |> json(%{response: :error, date: DateTime.utc_now(), errors: format_errors(cs)})
    end
  end

  def delete_scheduled_expense(%{query_params: %{"id" => id}} = conn, _params) do
    id |> String.to_integer() |> ScheduledExpenses.delete()
    conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: nil})
  end

  def run_scheduled(conn, _params) do
    %{scheduled_expenses: expenses, sinking_contributions: sinking} =
      ScheduledExpenses.run_scheduled()

    conn
    |> put_status(:ok)
    |> json(%{
      response:              :ok,
      date:                  DateTime.utc_now(),
      scheduled_expenses:    expenses,
      sinking_contributions: sinking,
    })
  end

  defp serialize(nil), do: nil
  defp serialize(se) do
    %{
      id:            se.id,
      bucket_id:     se.bucket_id,
      amount:        to_string(se.amount),
      description:   se.description,
      frequency:     se.frequency,
      day_of_month:  se.day_of_month,
      day_of_week:   se.day_of_week,
      month_of_year: se.month_of_year,
      next_due_date: Date.to_iso8601(se.next_due_date),
      active:        se.active,
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
