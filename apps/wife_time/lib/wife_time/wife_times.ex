defmodule WifeTime.WifeTimes do
  @topic "wife_time:wife_times"
  @schema WifeTime.WifeTimes.WifeTime
  @updated [:wife_time, :updated]
  @created [:wife_time, :created]
  @deleted [:wife_time, :deleted]

  use HfgPortal.Helpers.DefaultCrud, 
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def get_max_date() do
    @schema
    |> order_by(desc: :entry_date)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> Date.utc_today()
      item -> item.entry_date
    end
  end
end
