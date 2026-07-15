defmodule HfgPortalWeb.Apis.Budget.BucketsController do
  use HfgPortalWeb, :controller

  import HfgPortalWeb.Apis.ApiHelpers

  alias Budget.Buckets
  alias HfgPortalWeb.Apis.Budget.AuthController

  @routes [
    %{name: "buckets",  method: "GET",    function: &__MODULE__.list_buckets/2,  role: :view,  description: "List all buckets"},
    %{name: "bucket",   method: "GET",    function: &__MODULE__.get_bucket/2,    role: :view,  description: "Get a bucket by id"},
    %{name: "bucket",   method: "PUT",    function: &__MODULE__.put_bucket/2,    role: :admin, description: "Create or update a bucket"},
    %{name: "bucket",   method: "DELETE", function: &__MODULE__.delete_bucket/2, role: :admin, description: "Delete a bucket"},
  ]

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

  def list_buckets(%{query_params: query_params} = conn, _params) do
    with {:ok, search_stack} <- parse_search_stack(Map.get(query_params, "search_stack")),
         {:ok, sort_stack}   <- parse_sort_stack(Map.get(query_params, "sort_stack")) do
      buckets =
        Buckets.list(%{
          page:         Map.get(query_params, "page"),
          per_page:     Map.get(query_params, "per_page"),
          search_stack: search_stack,
          sort_stack:   sort_stack,
        })
        |> Enum.map(&serialize/1)
      conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: buckets})
    else
      {:error, msg} -> conn |> put_status(400) |> json(%{error: msg})
    end
  end

  def get_bucket(%{query_params: %{"id" => id}} = conn, _params) do
    bucket = id |> String.to_integer() |> Buckets.get()
    conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: serialize(bucket)})
  end

  def put_bucket(%{params: params} = conn, _params) do
    attrs = %{
      name:                 Map.get(params, "name"),
      description:          Map.get(params, "description"),
      type:                 Map.get(params, "type"),
      monthly_budget:       Map.get(params, "monthly_budget"),
      monthly_contribution: Map.get(params, "monthly_contribution"),
      max_balance:          Map.get(params, "max_balance"),
    }
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()

    base =
      case Map.get(params, "id") do
        nil -> Buckets.new() |> Map.put(:user_id, conn.assigns.current_api_user.id)
        id  -> id |> String.to_integer() |> Buckets.get()
      end

    attrs = if is_nil(Map.get(params, "id")), do: Map.put(attrs, :user_id, conn.assigns.current_api_user.id), else: attrs

    base
    |> Buckets.create_or_update(attrs)
    |> case do
      {:ok, bucket}  -> conn |> put_status(:ok) |> json(%{response: :ok,    date: DateTime.utc_now(), data: serialize(bucket)})
      {:error, cs}   -> conn |> put_status(:ok) |> json(%{response: :error, date: DateTime.utc_now(), errors: format_errors(cs)})
    end
  end

  def delete_bucket(%{query_params: %{"id" => id}} = conn, _params) do
    id |> String.to_integer() |> Buckets.delete()
    conn |> put_status(:ok) |> json(%{response: :ok, date: DateTime.utc_now(), data: nil})
  end

  defp serialize(nil), do: nil
  defp serialize(b) do
    %{
      id:                   b.id,
      name:                 b.name,
      type:                 b.type,
      description:          b.description,
      balance:              to_string(b.balance),
      monthly_budget:       decimal_or_nil(b.monthly_budget),
      monthly_contribution: decimal_or_nil(b.monthly_contribution),
      max_balance:          decimal_or_nil(b.max_balance),
      user_id:              b.user_id,
    }
  end

  defp decimal_or_nil(nil), do: nil
  defp decimal_or_nil(d),   do: to_string(d)

  defp format_errors(cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
  end

end
