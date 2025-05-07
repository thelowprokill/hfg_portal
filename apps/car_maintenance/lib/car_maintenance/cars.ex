defmodule CarMaintenance.Cars do
  @topic  "car_maintenance:cars"
  @schema  CarMaintenance.Cars.Car
  @updated [:car, :updated]
  @created [:car, :created]
  @deleted [:car, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted
end
