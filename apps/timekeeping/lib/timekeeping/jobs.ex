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

  def list(opts \\ %{}) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> order_by([j], j.name)
    |> filter_active(Map.get(opts, :active))
    |> filter_archive(Map.get(opts, :archive))
    |> HfgPortal.Repo.all()
    |> hfg_preload(Map.get(opts, :preload, []))
  end
end
