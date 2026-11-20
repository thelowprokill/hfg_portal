defmodule HfgPortalWeb.UserLoginLiveTest do
  use HfgPortalWeb.ConnCase

  import HfgPortal.AccountsFixtures

  # Plain requests (the LiveView's first render) rather than Phoenix.LiveViewTest, which needs
  # Floki. Submitting the form is a regular POST, covered in UserSessionControllerTest.
  describe "Log in page" do
    test "renders a username and password form", %{conn: conn} do
      html = conn |> get(~p"/users/log_in") |> html_response(200)

      assert html =~ "Sign in to account"
      assert html =~ ~s(name="user[username]")
      assert html =~ ~s(name="user[password]")
      refute html =~ "Forgot your password?"
      refute html =~ "Register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/log_in")
      assert redirected_to(conn) == ~p"/"
    end
  end
end
