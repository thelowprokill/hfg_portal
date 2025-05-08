defmodule HfgPortal.Helpers.Utility do
  import Ecto.Query

  def hfg_paginate(query, page, per_page) when not is_nil(page) and not is_nil(per_page) do
    query
    |> limit(^(per_page))
    |> offset(^(page * per_page))
  end
  def hfg_paginate(query, _page, _per_page), do: query

  def hfg_preload(query, items) when is_list(items), do: query |> HfgPortal.Repo.preload(items)
  def hfg_preload(query, _), do: query
end
