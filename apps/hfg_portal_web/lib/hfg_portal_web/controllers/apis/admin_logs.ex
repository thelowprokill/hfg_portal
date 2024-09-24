defmodule HfgPortalWeb.Apis.AdminLogsApiController do
  use HfgPortalWeb, :controller

  #alias Accounts.Authenticate
  #alias PlugsApp.{
  #  PythonLockTables
  #}

  alias AdminLogs.{
    AdminLogs
  }

  # temp hardcoded user until api users are set up
  def update(conn, 
    %{
      "username" => "python_api_user",
      "password" => "QvygFwKzEbEz7cFAkj35TaER6GXrDyEXURxdM9D3HqSjmubC2L9oGvrFXtxWzP3aVpi8VnnFqGHe6pHA3MESoM8qvBKUavFrJTRoM5CENJgung8GnzKTqZjd6Qj4zVcp"
    }) do

      #%{
      #  provider: :identity,
      #  extra: %{
      #    raw_info: %{
      #      "user" => %{
      #        "username" => user,
      #        "password" => password
      #      }
      #    }
      #  }
      #}
      #|> Authenticate.authenticate()
      #|> case do
      #     {:ok, %{name: "python_api_user"}} ->
      #       table_id
      #       |> PythonLockTables.get(:table)
      #       |> PythonLockTables.create_or_update(%{last_index: String.to_integer(value)})

      #       conn
      #       |> put_status(204)
      #       |> send_resp(:no_content, "")
      #     _ ->
      #       conn
      #       |> put_status(404)
      #       |> send_resp(:no_content, "")
      #   end
    

    AdminLogs.update()

    conn
    |> put_status(204)
    |> send_resp(:no_content, "")

  end

  def update(conn, _params) do
    conn
    |> put_status(404)
    |> send_resp(:no_content, "")
  end
end
