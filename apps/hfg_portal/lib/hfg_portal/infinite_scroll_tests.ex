defmodule HfgPortal.InfiniteScrollTest do
  @topic "hfg_portal:item"
  @schema HfgPortal.InfiniteScrollTest.Item
  @updated [:item, :updated]
  @created [:item, :created]
  @deleted [:item, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted
end
