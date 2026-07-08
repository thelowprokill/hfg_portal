defmodule HfgPortalWeb.Apis.TaskAutomationControllerApiController do
  use HfgPortalWeb, :controller

  alias TaskAutomationController.{
    QueuedItems
  }

  # temp hardcoded user until api users are set up
  def update(conn, 
    %{
      "username" => "python_api_user",
      "password" => "QvygFwKzEbEz7cFAkj35TaER6GXrDyEXURxdM9D3HqSjmubC2L9oGvrFXtxWzP3aVpi8VnnFqGHe6pHA3MESoM8qvBKUavFrJTRoM5CENJgung8GnzKTqZjd6Qj4zVcp"
    }) do

    QueuedItems.update()

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
