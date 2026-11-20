defmodule Timekeeping.Jobs do
  import Ecto.Query

  @topic   "timekeeping:jobs"
  @schema  Timekeeping.Jobs.Job
  @updated [:job, :updated]
  @created [:job, :created]
  @deleted [:job, :deleted]

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
    |> order_by([j], j.name)
    |> filter_active(Map.get(opts, :active))
    |> filter_archive(Map.get(opts, :archive))
    |> filter_user(Map.get(opts, :user_id))
    |> HfgPortal.Repo.all()
    |> hfg_preload(Map.get(opts, :preload, []))
  end

  defp filter_user(query, nil), do: query
  defp filter_user(query, user_id), do: query |> where([j], j.user_id == ^user_id)

  @doc "The job with `id` if it belongs to `user_id`, else nil."
  def get_for_user(id, user_id), do: HfgPortal.Repo.get_by(@schema, id: id, user_id: user_id)
end
