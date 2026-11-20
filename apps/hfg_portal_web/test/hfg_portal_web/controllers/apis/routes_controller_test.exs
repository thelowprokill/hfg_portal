defmodule HfgPortalWeb.Apis.RoutesControllerTest do
  use HfgPortalWeb.ApiCase

  import HfgPortal.AccountsFixtures, only: [valid_user_password: 0]

  # a route that answers 200 for a Budget viewer and touches nothing
  @ok_query %{"scope" => "budget:buckets", "route" => "buckets"}

  defp b64(map), do: map |> Jason.encode!() |> Base.url_encode64(padding: false)

  defp login(conn, username, password, method \\ :get),
    do: dispatch(conn, @endpoint, method, "/apis/call?" <> URI.encode_query(%{username: username, password: password}), nil)

  describe "login (username + password on /apis/call)" do
    test "returns a JWT for the user, and the apps they have a role in", %{conn: conn} do
      user = api_user(%{budget: "Edit", homm_saves: "Admin", loan_repayment: "None"})

      body = conn |> login(user.username, valid_user_password()) |> json_response(200)

      assert body["username"] == user.username
      assert Enum.sort_by(body["apps"], & &1["app"]) == [
               %{"app" => "Budget", "role" => "Edit"},
               %{"app" => "HoMM Saves", "role" => "Admin"}
             ]

      assert {:ok, claims} = Joken.verify(body["jwt"], Joken.Signer.create("HS256", secret()))
      assert claims["user_id"] == user.id
      assert claims["admin"] == false
    end

    test "the returned JWT authenticates later calls", %{conn: conn} do
      user = api_user(%{budget: "View"})
      %{"jwt" => jwt} = conn |> login(user.username, valid_user_password()) |> json_response(200)

      assert build_conn() |> api("GET", jwt, @ok_query) |> data() == []
    end

    test "works on PUT and DELETE too (any /apis/call method)", %{conn: conn} do
      user = api_user()

      for method <- [:put, :delete] do
        assert %{"username" => username} = conn |> login(user.username, valid_user_password(), method) |> json_response(200)
        assert username == user.username
      end
    end

    test "a user with no app roles gets an empty app list", %{conn: conn} do
      user = api_user()
      assert %{"apps" => [], "jwt" => jwt} = conn |> login(user.username, valid_user_password()) |> json_response(200)
      assert is_binary(jwt)
    end

    test "wrong password, unknown user and inactive user all get no token", %{conn: conn} do
      user = api_user(%{budget: "Admin"})
      inactive = api_user(%{budget: "Admin"}, %{active: false})
      empty = %{"jwt" => nil, "username" => nil, "apps" => []}

      assert conn |> login(user.username, "not the password") |> json_response(200) == empty
      assert conn |> login("nobody#{System.unique_integer()}", valid_user_password()) |> json_response(200) == empty
      assert conn |> login(inactive.username, valid_user_password()) |> json_response(200) == empty
    end

    test "username alone is not a login, it falls through to JWT auth", %{conn: conn} do
      user = api_user()
      conn |> dispatch(@endpoint, :get, "/apis/call?username=#{user.username}", nil) |> assert_rejected()
    end

    test "the login JWT expires", %{conn: conn} do
      user = api_user()
      %{"jwt" => jwt} = conn |> login(user.username, valid_user_password()) |> json_response(200)
      {:ok, claims} = Joken.peek_claims(jwt)
      assert is_integer(claims["exp"])
      assert claims["exp"] > System.system_time(:second)
    end
  end

  describe "JWT auth on /apis/call" do
    setup do
      user = api_user(%{budget: "View"})
      %{user: user, jwt: token(user)}
    end

    test "a valid token for a user with the role is dispatched to the scope's controller", %{conn: conn, jwt: jwt} do
      assert conn |> api("GET", jwt, @ok_query) |> data() == []
    end

    test "no x-api-key header is rejected", %{conn: conn} do
      conn |> api("GET", nil, @ok_query) |> assert_rejected()
    end

    test "missing or unknown scope is rejected", %{conn: conn, jwt: jwt} do
      conn |> api("GET", jwt, %{"route" => "buckets"}) |> assert_rejected()
      conn |> api("GET", jwt, %{"scope" => "nope", "route" => "buckets"}) |> assert_rejected()
    end

    test "a garbage token is rejected", %{conn: conn} do
      for bad <- ["", "garbage", "a.b.c", "Bearer x"] do
        conn |> api("GET", bad, @ok_query) |> assert_rejected()
      end
    end

    test "a token signed with another secret is rejected", %{conn: conn, user: user} do
      jwt = sign(%{"user_id" => user.id, "admin" => false}, "not-the-secret")
      conn |> api("GET", jwt, @ok_query) |> assert_rejected()
    end

    test "a tampered payload (other user / admin) keeps the old signature and is rejected", %{conn: conn, jwt: jwt} do
      other = api_user(%{budget: "Admin"})
      [header, _payload, sig] = String.split(jwt, ".")

      for claims <- [%{"user_id" => other.id, "admin" => false}, %{"user_id" => other.id, "admin" => true}] do
        conn |> api("GET", Enum.join([header, b64(claims), sig], "."), @ok_query) |> assert_rejected()
      end
    end

    test "an unsigned alg=none token is rejected", %{conn: conn, user: user} do
      jwt = b64(%{"alg" => "none", "typ" => "JWT"}) <> "." <> b64(%{"user_id" => user.id, "admin" => true}) <> "."
      conn |> api("GET", jwt, @ok_query) |> assert_rejected()
    end

    test "a validly signed token without user_id/admin/exp claims is rejected", %{conn: conn, user: user} do
      exp = System.system_time(:second) + 60
      conn |> api("GET", sign(%{"user_id" => user.id, "exp" => exp}), @ok_query) |> assert_rejected()
      conn |> api("GET", sign(%{"admin" => false, "exp" => exp}), @ok_query) |> assert_rejected()
      # pre-exp tokens (issued before expiry was added) no longer work
      conn |> api("GET", sign(%{"user_id" => user.id, "admin" => false}), @ok_query) |> assert_rejected()
    end

    test "the token must be in x-api-key, not Authorization", %{conn: conn, jwt: jwt} do
      conn
      |> put_req_header("authorization", "Bearer " <> jwt)
      |> api("GET", nil, @ok_query)
      |> assert_rejected()
    end

    test "the hfg_portal scope requires a portal admin", %{conn: conn, jwt: jwt} do
      conn |> api("GET", jwt, %{"scope" => "hfg_portal"}) |> assert_rejected()
    end

    test "unauthenticated calls answer 401", %{conn: conn} do
      assert conn |> api("GET", nil, @ok_query) |> response(401)
    end

    test "an expired token is rejected", %{conn: conn, user: user} do
      jwt = token(user, %{"exp" => System.system_time(:second) - 60})
      conn |> api("GET", jwt, @ok_query) |> assert_rejected()
    end

    test "a deactivated user's token is rejected", %{conn: conn, user: user, jwt: jwt} do
      {:ok, _} = HfgPortal.Accounts.create_or_update(user, %{active: false})
      conn |> api("GET", jwt, @ok_query) |> assert_rejected()
    end

    test "a token for a user that doesn't exist is rejected", %{conn: conn} do
      conn |> api("GET", token(%{id: -1}), @ok_query) |> assert_rejected()
    end

    test "the hfg_portal scope answers a portal admin", %{conn: conn} do
      admin = api_user(%{}, %{portal_admin: true})
      task = Task.async(fn -> api(conn, "GET", token(admin), %{"scope" => "hfg_portal"}) end)
      assert {:ok, %Plug.Conn{state: :sent}} = Task.yield(task, 2_000) || Task.shutdown(task, :brutal_kill)
    end

    test "a missing route answers 404", %{conn: conn, jwt: jwt} do
      assert %{"error" => "Route not found"} = conn |> api("GET", jwt, %{"scope" => "budget:buckets"}) |> json_response(404)
    end
  end

  describe "GET /apis/task_automation_controller/update" do
    @old_hardcoded_password "QvygFwKzEbEz7cFAkj35TaER6GXrDyEXURxdM9D3HqSjmubC2L9oGvrFXtxWzP3aVpi8VnnFqGHe6pHA3MESoM8qvBKUavFrJTRoM5CENJgung8GnzKTqZjd6Qj4zVcp"

    setup do
      old = {System.get_env("TAC_API_USERNAME"), System.get_env("TAC_API_PASSWORD")}
      System.put_env("TAC_API_USERNAME", "python_api_user")
      System.put_env("TAC_API_PASSWORD", "test-tac-password")

      on_exit(fn ->
        for {k, v} <- Enum.zip(["TAC_API_USERNAME", "TAC_API_PASSWORD"], Tuple.to_list(old)),
            do: if(v, do: System.put_env(k, v), else: System.delete_env(k))
      end)

      TaskAutomationController.QueuedItems.subscribe()
    end

    defp tac_update(conn, query), do: get(conn, "/apis/task_automation_controller/update?" <> URI.encode_query(query))

    test "the env credentials trigger an update", %{conn: conn} do
      assert conn |> tac_update(%{username: "python_api_user", password: "test-tac-password"}) |> response(204)
      assert_received {[:queued_item, :updated], _}
    end

    test "without the env credentials it sends nothing and doesn't trigger an update", %{conn: conn} do
      for query <- [%{}, %{username: "python_api_user"}, %{username: "python_api_user", password: "wrong"},
                    %{username: "someone_else", password: "test-tac-password"}] do
        conn = tac_update(conn, query)
        assert conn.resp_body == ""
        refute_received {[:queued_item, :updated], _}
      end
    end

    test "the old hardcoded password no longer works", %{conn: conn} do
      assert conn |> tac_update(%{username: "python_api_user", password: @old_hardcoded_password}) |> response(404)
      refute_received {[:queued_item, :updated], _}
    end

    test "with the env vars unset nothing gets in, not even empty credentials", %{conn: conn} do
      System.delete_env("TAC_API_USERNAME")
      System.delete_env("TAC_API_PASSWORD")

      for query <- [%{username: "python_api_user", password: "test-tac-password"}, %{username: "", password: ""}] do
        assert conn |> tac_update(query) |> response(404)
      end

      refute_received {[:queued_item, :updated], _}
    end

    test "bad credentials answer 404", %{conn: conn} do
      assert conn |> get("/apis/task_automation_controller/update") |> response(404)
    end
  end
end
