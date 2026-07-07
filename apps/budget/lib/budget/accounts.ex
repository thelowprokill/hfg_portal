defmodule Budget.Accounts do
  import Ecto.Query

  @topic "budget:accounts"
  @schema Budget.Accounts.Account
  @updated [:account, :updated]
  @created [:account, :created]
  @deleted [:account, :deleted]

  use HfgPortal.Helpers.DefaultCrud,
    schema: @schema,
    topic: @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def list(opts) do
    @schema
    |> search_stack(Map.get(opts, :search_stack))
    |> sort_stack(Map.get(opts, :sort_stack))
    |> hfg_paginate(Map.get(opts, :page), Map.get(opts, :per_page))
    |> order_by([a], a.name)
    |> filter_active(Map.get(opts, :active))
    |> filter_archive(Map.get(opts, :archive))
    |> HfgPortal.Repo.all()
    |> hfg_preload(Map.get(opts, :preload, []))
  end
end
