defmodule HfgPortalWeb.Apis.RoutesController do
  use HfgPortalWeb, :controller


  @scopes [
    %{name: "hfg_portal",                      module: HfgPortalWeb.Apis.RoutesController},
    %{name: "car_maintenance:cars",            module: HfgPortalWeb.Apis.CarMaintenance.CarController},
    %{name: "car_maintenance:service_history", module: HfgPortalWeb.Apis.CarMaintenance.ServiceHistoryController},
  ]

  def scopes(conn, _params) do
    json(conn, %{
      "scopes" => 
        @scopes
        |> Enum.map(&(&1.name))
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
      is_nil(api_key) || is_nil(scope) -> nil
      true -> 
        signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET"))

        token_config = %{
          "scope" => %Joken.Claim{
            generate: fn -> "user" end,
            validate: fn val, _claims, _context -> val in ["u", "a"] end
          }
        }

        {:ok, %{"user_id" => user_id, "admin" => admin}} = Joken.verify(api_key, signer)

        user = HfgPortal.Accounts.get_user!(user_id)

        # authenticate the user with the scope
        cond do
          admin || user.portal_admin -> scope
          true -> nil
        end
    end
  end
end
