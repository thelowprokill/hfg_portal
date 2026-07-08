defmodule TaskAutomationController.Roles do
  @topic "task_automation_controller:roles"
  @schema TaskAutomationController.Users.Role
  @updated [:role, :updated]
  @created [:role, :created]
  @deleted [:role, :deleted]

  # Include default CRUD operations from HfgPortal.Helpers.DefaultCrud
  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  #def list(opts) do
  #  @schema
  #  |> search_stack(Map.get(opts, :search_stack))
  #  |> sort_stack(Map.get(opts, :sort_stack))
  #  |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
  #  |> filter_active(Map.get(opts, :active))
  #  |> where([qi], qi.status in ["unassigned", "waiting", "running"])
  #  |> Repo.all()
  #  |> HfgPortal.Helpers.Utility.hfg_preload(Map.get(opts, :preload, []))
  #end
end
