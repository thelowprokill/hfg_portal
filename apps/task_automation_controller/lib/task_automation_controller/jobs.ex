defmodule TaskAutomationController.Jobs do
  @topic "task_automation_controller:jobs"
  @schema TaskAutomationController.Jobs.Job
  @updated [:job, :updated]
  @created [:job, :created]
  @deleted [:job, :deleted]

  # Include default CRUD operations from HfgPortal.Helpers.DefaultCrud
  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  defp filter_user_jobs(query, user_id) when not is_nil(user_id) do
    has_admin = TaskAutomationController.Users.UserRole
      |> join(:inner, [ur], r in TaskAutomationController.Users.Role, on: ur.role_id == r.id)
      |> where([ur, r], ur.user_id == ^user_id and r.admin == true)
      |> HfgPortal.Repo.exists?()

    if has_admin do
      query
    else
      # a subquery, not joins, so a job linked through several of the user's roles is listed once
      job_ids =
        TaskAutomationController.Users.RoleJob
        |> join(:inner, [rj], ur in TaskAutomationController.Users.UserRole, on: rj.role_id == ur.role_id)
        |> where([_, ur], ur.user_id == ^user_id)
        |> select([rj], rj.job_id)

      query |> where([j], j.id in subquery(job_ids))
    end
  end
  defp filter_user_jobs(query, _), do: query

  def list(opts) do
    @schema
    |> filter_user_jobs(Map.get(opts, :user_id))
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> filter_active(Map.get(opts, :active))
    |> HfgPortal.Repo.all()
    |> hfg_preload(Map.get(opts, :preload, []))
  end
end
