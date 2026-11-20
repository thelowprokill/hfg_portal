defmodule HfgPortalWeb.ApiCase do
  @moduledoc """
  Request-level tests for the JSON API under `/apis`.

  Checks out every app repo in the SQL sandbox (the API touches several), and gives helpers to
  make users with per-app roles, sign JWTs the way `/apis/call` login does, and call the
  `/apis/call` dispatcher with an `x-api-key` header.

  Not async: the dispatcher reads `JWT_SECRET` and homm_saves reads `HOMM_SAVES_DIR` from the
  environment.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint HfgPortalWeb.Endpoint

      import Plug.Conn
      import Phoenix.ConnTest
      import HfgPortalWeb.ApiCase
    end
  end

  @repos [
    Budget.Repo,
    CarMaintenance.Repo,
    LoanRepayment.Repo,
    HommSaves.Repo,
    TaskAutomationController.Repo,
    WifeTime.Repo,
    Timekeeping.Repo
  ]

  setup tags do
    HfgPortal.DataCase.setup_sandbox(tags)

    for repo <- @repos do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(repo, shared: not tags[:async])
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    end

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @user_roles %{
    budget:          Budget.UserRoles,
    car_maintenance: CarMaintenance.UserRoles,
    loan_repayment:  LoanRepayment.UserRoles,
    homm_saves:      HommSaves.UserRoles
  }

  @doc "A portal user with the given app roles, e.g. `api_user(%{budget: \"Admin\"})`."
  def api_user(roles \\ %{}, attrs \\ %{}) do
    user = HfgPortal.AccountsFixtures.user_fixture(attrs)

    for {app, role} <- roles do
      mod = Map.fetch!(@user_roles, app)
      {:ok, _} = mod.create_or_update(mod.new(), %{user_id: user.id, role: role})
    end

    user
  end

  def secret, do: System.fetch_env!("JWT_SECRET")

  @doc "Signs `claims` (HS256) - by default the claims login hands out for `user`."
  def sign(claims, key \\ secret()) do
    {:ok, jwt, _} = Joken.encode_and_sign(claims, Joken.Signer.create("HS256", key))
    jwt
  end

  def token(user, extra \\ %{}),
    do: sign(Map.merge(%{"user_id" => user.id, "admin" => false, "exp" => System.system_time(:second) + 3600}, extra))

  @doc """
  Calls `/apis/call` with `query` in the query string (the controllers read `query_params`) and
  `body` as body params (used for uploads). `token` nil sends no `x-api-key`.
  """
  def api(conn, method, token, query, body \\ nil) do
    conn = if token, do: Plug.Conn.put_req_header(conn, "x-api-key", token), else: conn
    Phoenix.ConnTest.dispatch(conn, HfgPortalWeb.Endpoint, method, "/apis/call?" <> URI.encode_query(query), body)
  end

  @doc "The dispatcher's rejection: no controller ran and nothing was sent back."
  def assert_rejected(conn) do
    assert conn.resp_body == ""
    assert conn.status == 401
    conn
  end

  def data(conn, status \\ 200) do
    body = Phoenix.ConnTest.json_response(conn, status)
    assert body["response"] == "ok"
    body["data"]
  end
end
