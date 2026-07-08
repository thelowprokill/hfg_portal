defmodule TaskAutomationController.Priorities do
  @topic "task_automation_controller:priorities"
  @schema TaskAutomationController.Jobs.Priority
  @updated [:priority, :updated]
  @created [:priority, :created]
  @deleted [:priority, :deleted]

  # Include default CRUD operations from HfgPortal.Helpers.DefaultCrud
  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def list(opts) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> order_by(desc: :order)
    |> Repo.all()
  end
end
