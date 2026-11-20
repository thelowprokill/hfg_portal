defmodule HfgPortalWeb.PageControllerTest do
  use HfgPortalWeb.ConnCase

  import HfgPortal.AccountsFixtures

  test "GET / sends a signed-out visitor to log in", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/users/log_in"
  end

  test "GET / renders for a signed-in user", %{conn: conn} do
    conn = conn |> log_in_user(user_fixture()) |> get(~p"/")
    assert html_response(conn, 200)
  end
end
