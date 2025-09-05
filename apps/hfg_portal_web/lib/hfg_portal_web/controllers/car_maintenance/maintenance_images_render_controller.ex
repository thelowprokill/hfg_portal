defmodule HfgPortalWeb.CarMaintenance.MaintenanceImageRenderController do
  use HfgPortalWeb, :controller

  alias CarMaintenance.{
    Cars.MaintenanceImage,
    MaintenanceImages,
  }

  def image(conn, %{"id" => id}) do
    case MaintenanceImages.get(id) do
      %MaintenanceImage{image: image, image_content_type: image_type} ->
        conn
        |> put_resp_content_type("image/#{image_type}")
        |> send_resp(200, image)
      _ ->
        conn
        |> send_resp(404, "")
    end
  end
end
