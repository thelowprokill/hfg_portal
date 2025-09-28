defmodule HfgPortalWeb.Apis.RoutesController do
  use HfgPortalWeb, :controller


  @scopes [
    %{name: "hfg_portal",                      module: HfgPortalWeb.Apis.RoutesController},
    %{name: "car_maintenance:cars",            module: HfgPortalWeb.Apis.CarMaintenance.CarController},
    %{name: "car_maintenance:service_history", module: HfgPortalWeb.Apis.CarMaintenance.ServiceHistoryController},
  ]

  def scopes(conn, _params) do
    json(conn, %{
      "scopes" => [
        "hfg_portal",
      ]
    })
  end

  def call(conn, params) do
    auth(conn)
    |> case do
      %{module: module} -> 
        module.call(conn, params)
      _ ->
        conn
        |> put_status(401)
        |> send_resp(:no_content, "")
    end
  end

  defp auth(%{req_headers: headers, query_params: %{"scope" => scope} = params}) do
    api_key = Enum.find(headers, fn {k, _} -> k == "x-api-key" end) |> elem(1)

    scope = Enum.find(@scopes, &(&1.name == scope))

    cond do
      is_nil(api_key)   -> nil
      is_nil(scope)     -> nil
      api_key != "1234" -> nil
      true              -> scope
    end
  end
end
