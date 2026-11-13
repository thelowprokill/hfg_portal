defmodule CarMaintenance.Cars.MaintenanceImage do
  use Ecto.Schema
  import Ecto.Changeset

  prefix = "car_maintenance"
  prefix = case Application.compile_env(:car_maintenance, :env) do
    :dev   -> prefix <> "_dev"
    :test  -> prefix <> "_test"
    :trial -> prefix <> "_trial"
    _      -> prefix
  end

  @schema_prefix prefix

  schema "maintenance_images" do
    field      :name,               :string
    belongs_to :service_history,    CarMaintenance.Cars.ServiceHistory
    field      :image,              :binary
    field      :image_content_type, :string
    belongs_to :created_by,         CarMaintenance.Users.User
    belongs_to :updated_by,         CarMaintenance.Users.User

    timestamps()
  end

  def changeset(image, attrs \\ %{}) do
    image
    |> cast(attrs, [
      :name,
      :service_history_id,
      :image,
      :image_content_type,
      :created_by_id,
      :updated_by_id,
    ])
  end
end
