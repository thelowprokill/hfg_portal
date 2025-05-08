defmodule HfgPortal.ApiAccounts do
  @moduledoc """
  The Accounts context.
  """

  @topic "bnwportal:api_users"
  @schema HfgPortal.Accounts.ApiUser
  @updated [:user, :updated]
  @created [:user, :created]
  @deleted [:user, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted
end
