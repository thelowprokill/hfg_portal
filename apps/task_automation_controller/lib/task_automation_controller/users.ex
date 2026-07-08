defmodule TaskAutomationController.Users do
  @topic "task_automation_controller:users"
  @schema TaskAutomationController.Users.User
  @updated [:user, :updated]
  @created [:user, :created]
  @deleted [:user, :deleted]

  # Include default CRUD operations from HfgPortal.Helpers.DefaultCrud
  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  #defp filter_job_id(query, job_id) when not is_nil(job_id), do: query |> where(job_id: ^job_id)
  #defp filter_job_id(query, _job_id), do: query
  #
  #def list(opts) do
  #  @schema
  #  |> search_stack(Map.get(opts, :search_stack))
  #  |> sort_stack(Map.get(opts, :sort_stack))
  #  |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
  #  |> filter_active(Map.get(opts, :active))
  #  |> filter_job_id(Map.get(opts, :job_id))
  #  |> Repo.all()
  #end
end
