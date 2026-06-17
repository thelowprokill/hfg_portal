defmodule HfgPortalWeb.Apis.RoutesController do
  use HfgPortalWeb, :controller

  alias HfgPortal.Accounts
  alias HfgPortal.Accounts.User

  @scopes [
    %{name: "hfg_portal",                         module: HfgPortalWeb.Apis.RoutesController},

    %{name: "car_maintenance:cars",               module: HfgPortalWeb.Apis.CarMaintenance.CarController,               require_admin: false},
    %{name: "car_maintenance:service_history",    module: HfgPortalWeb.Apis.CarMaintenance.ServiceHistoryController,    require_admin: false},
    %{name: "car_maintenance:maintenance_items",  module: HfgPortalWeb.Apis.CarMaintenance.MaintenanceItemsController,  require_admin: false},
    %{name: "car_maintenance:maintenance_images", module: HfgPortalWeb.Apis.CarMaintenance.MaintenanceImagesController, require_admin: false},

    %{name: "budget",                             module: HfgPortalWeb.Apis.Budget.BudgetController,            require_admin: false},
    %{name: "budget:buckets",                     module: HfgPortalWeb.Apis.Budget.BucketsController,           require_admin: false},
    %{name: "budget:transactions",                module: HfgPortalWeb.Apis.Budget.TransactionsController,      require_admin: false},
    %{name: "budget:scheduled_expenses",          module: HfgPortalWeb.Apis.Budget.ScheduledExpensesController, require_admin: false},
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

        apps = HfgPortalWeb.Layout.SidebarLive.list_apps(user) |> Enum.map(&(%{app: &1.name, role: app_role(&1.id, id)})) |> Enum.reject(&(is_nil(&1.role) || &1.role not in ["View", "Edit", "Admin"]))

        conn
        |> put_status(:ok)
        |> json(%{jwt: jwt, username: username, apps: apps})
      _ ->
        conn
        |> put_status(:ok)
        |> json(%{jwt: nil, username: nil, apps: []})
    end
  end

  def call(conn, params) do
    auth(conn)
    |> case do
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

  defp app_role(app_id, user_id) do
    user_roles_mod = case app_id do
      "budget"          -> Budget.UserRoles
      "car_maintenance" -> CarMaintenance.UserRoles
      #"loan_repayment"  -> LoanRepayment.UserRoles
      #"wife_time"       -> WifeTime.UserRoles
      _                 -> nil
    end

    case user_roles_mod do
      nil -> nil
      mod ->
        case mod.get(user_id, :user) do
          nil       -> nil
          user_role -> user_role.role
        end
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
              true                                          -> {scope, user}
            end
          _ -> nil
        end
    end
  end
  defp auth(_), do: nil
end
