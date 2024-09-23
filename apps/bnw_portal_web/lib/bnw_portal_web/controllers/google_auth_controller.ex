defmodule BnwPortalWeb.GoogleAuthController do
  use BnwPortalWeb, :controller

  alias BnwPortal.Accounts
  alias BnwPortalWeb.UserAuth

  @doc """
  `index/2` handles the callback from Google Auth API redirect.
  """
  def index(conn, %{"code" => code}) do
    base_url =
      case Application.get_env(:bnw_portal_web, :environment) do
        "production" ->
          BnwPortalWeb.Endpoint.url()
          |> String.replace("http:", "https:")
          |> String.replace(":4000", "")
        _ -> BnwPortalWeb.Endpoint.url()
      end
    {:ok, token} = ElixirAuthGoogle.get_token(code, base_url)
    {:ok, profile} = ElixirAuthGoogle.get_user_profile(token.access_token)

    user_email = Map.get(profile, :email)

    cond do
      user = Accounts.get_active_user_by_email(user_email) ->
        conn
        |> put_flash(:info, "Signed in as #{user.username}")
        |> UserAuth.log_in_user(user)
      is_nil(Accounts.get_user_by_email(user_email))
          and String.contains?(user_email, ["@beefnw.com", "@nbxtrucking.com", "@carltonfarms.com"]) ->
        case Accounts.create_user_with_google_profile(profile) do
          {:ok, user} ->
            conn
            |> put_flash(:info, "Signed in as #{user.username}")
            |> UserAuth.log_in_user(user)
          _ ->
            conn
            |> put_flash(:error, "Unable to login with Google")
            |> redirect(to: ~p"/users/log_in")
        end
      true ->
        # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
        conn
        |> put_flash(:error, "Unable to login with Google")
        |> redirect(to: ~p"/users/log_in")
    end

    conn
    |> redirect(to: ~p"/")
  end
end
