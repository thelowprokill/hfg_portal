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

  def list_for_user(user_id) do
    @schema
    |> where([b], b.user_id == ^user_id)
    |> order_by([b], b.name)
    |> Repo.all()
  end

  def list_sinking_funds(user_id) do
    @schema
    |> where([b], b.user_id == ^user_id and not is_nil(b.monthly_contribution))
    |> order_by([b], b.name)
    |> Repo.all()
  end

  def list_all_sinking_funds do
    @schema
    |> where([b], not is_nil(b.monthly_contribution))
    |> order_by([b], b.name)
    |> Repo.all()
  end
end
