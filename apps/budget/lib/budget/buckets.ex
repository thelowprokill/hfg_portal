defmodule Budget.Buckets do
  import Ecto.Query

  @topic   "budget:buckets"
  @schema  Budget.Buckets.Bucket
  @updated [:bucket, :updated]
  @created [:bucket, :created]
  @deleted [:bucket, :deleted]

  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def list_all_sinking_funds do
    @schema
    |> where([b], b.type == "sinking_fund")
    |> order_by([b], b.name)
    |> Repo.all()
  end

  def list_all_emergency_funds do
    @schema
    |> where([b], b.type == "emergency_fund")
    |> order_by([b], b.name)
    |> Repo.all()
  end

  def list(opts) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> order_by([b], b.name)
    |> filter_active(Map.get(opts, :active))
    |> filter_archive(Map.get(opts, :archive))
    |> HfgPortal.Repo.all()
    |> hfg_preload(Map.get(opts, :preload, []))
  end
end
