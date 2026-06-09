defmodule HfgPortalWeb.Apis.RoutesController do
  use HfgPortalWeb, :controller

  alias HfgPortal.Accounts
  alias HfgPortal.Accounts.User

  @scopes [
    %{name: "hfg_portal",                         module: HfgPortalWeb.Apis.RoutesController},

    %{name: "car_maintenance:cars",               module: HfgPortalWeb.Apis.CarMaintenance.CarController},
    %{name: "car_maintenance:service_history",    module: HfgPortalWeb.Apis.CarMaintenance.ServiceHistoryController},
    %{name: "car_maintenance:maintenance_items",  module: HfgPortalWeb.Apis.CarMaintenance.MaintenanceItemsController},
    %{name: "car_maintenance:maintenance_images", module: HfgPortalWeb.Apis.CarMaintenance.MaintenanceImagesController},

    %{name: "budget",                             module: HfgPortalWeb.Apis.Budget.BudgetController,             require_admin: false},
    %{name: "budget:buckets",                     module: HfgPortalWeb.Apis.Budget.BucketsController,            require_admin: false},
    %{name: "budget:transactions",                module: HfgPortalWeb.Apis.Budget.TransactionsController,       require_admin: false},
    %{name: "budget:scheduled_expenses",          module: HfgPortalWeb.Apis.Budget.ScheduledExpensesController,  require_admin: false},
  ]

  def scopes(conn, _params) do
    json(conn, %{
      "scopes" =>
        @scopes
        |> Enum.map(&(&1.name))
    })
  end

  # auth request
  def call(%{query_params: %{"username" => username, "password" => password}} = conn, params) do
    user = Accounts.get_active_user_by_username_and_password(username, password)

    IO.puts ""
    IO.puts ""
    IO.puts ""
    IO.puts "{{{{{{{{{{{{{{{{{{{{{{{{{{ user }}}}}}}}}}}}}}}}}}}}}}}}}}"
    IO.inspect username
    IO.inspect user
    IO.puts "{{{{{{{{{{{{{{{{{{{{{{{{{{ user }}}}}}}}}}}}}}}}}}}}}}}}}}"
    IO.puts ""
    IO.puts ""
    IO.puts ""

    case user do
      %User{id: id, username: username} ->
        token_config = Map.put(%{}, "scope", %Joken.Claim{
          generate: fn -> "user" end,
          validate: fn val, _claims, _context -> val in ["u", "a"] end
        })
        signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET"))

        {:ok, claims} = Joken.generate_claims(token_config, %{
          user_id:    id,
          admin:      false,
          updated_at: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%dT%H:%M:%S"),
        })
        {:ok, jwt, _claims} = Joken.encode_and_sign(claims, signer)

        conn
        |> put_status(:ok)
        |> json(%{jwt: jwt, username: username})
      _ ->
        conn
        |> put_status(:ok)
        |> json(%{jwt: nil, username: nil})
    end
  end

  def call(conn, params) do
    case auth(conn) do
      {%{module: module}, user} ->
        conn
        |> assign(:current_api_user, user)
        |> module.call(params)
      _ ->
        conn
        |> put_status(401)
        |> send_resp(:no_content, "")
    end
  end

  defp auth(%{req_headers: headers, query_params: %{"scope" => scope_name} = _params}) do
    api_key = Enum.find(headers, fn {k, _} -> k == "x-api-key" end)
    scope   = Enum.find(@scopes, &(&1.name == scope_name))

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

        {_, jwt} = api_key

        case Joken.verify(jwt, signer) do
          {:ok, %{"user_id" => user_id, "admin" => admin}} ->
            user          = HfgPortal.Accounts.get_user!(user_id)
            require_admin = Map.get(scope, :require_admin, true)

            cond do
              require_admin && !admin && !user.portal_admin -> nil
              true -> {scope, user}
            end
          _ -> nil
        end
    end
  end
  defp auth(_), do: nil
end
