defmodule BnwPortal.Helpers.Utility do
  import Ecto.Query

  def bnw_paginate(query, page, per_page) when not is_nil(page) and not is_nil(per_page) do
    query
    |> limit(^(per_page))
    |> offset(^(page * per_page))
  end
  def bnw_paginate(query, _page, _per_page), do: query

  def bnw_preload(query, items) when is_list(items), do: query |> BnwPortal.Repo.preload(items)
  def bnw_preload(query, _), do: query
end
