defmodule Timekeeping.TimeEntries do
  import Ecto.Query

  @topic   "timekeeping:time_entries"
  @schema  Timekeeping.TimeEntries.TimeEntry
  @updated [:time_entry, :updated]
  @created [:time_entry, :created]
  @deleted [:time_entry, :deleted]

  use HfgPortal.Helpers.DefaultCrud,
    schema:  @schema,
    topic:   @topic,
    updated: @updated,
    created: @created,
    deleted: @deleted

  def list_for_job(job_id) do
    @schema
    |> where([te], te.job_id == ^job_id)
    |> order_by([te], desc: te.start_time)
    |> Repo.all()
  end

  def get_open_for_job(job_id) do
    @schema
    |> where([te], te.job_id == ^job_id and is_nil(te.end_time))
    |> Repo.one()
  end

  @doc """
  Returns a map of job_id => start_time for every job that currently has an
  open (running) time entry.
  """
  def open_job_starts do
    @schema
    |> where([te], is_nil(te.end_time))
    |> select([te], {te.job_id, te.start_time})
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Starts a new time entry for `job_id`, first stopping any other entry the
  user currently has running (across all of their jobs) so only one timer
  is ever open at once.
  """
  def start_now(job_id, user_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    stop_open_entries_for_user(user_id, now)
    new() |> create_or_update(%{job_id: job_id, start_time: now})
  end

  def stop_now(entry_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    get(entry_id) |> create_or_update(%{end_time: now})
  end

  defp stop_open_entries_for_user(user_id, now) do
    ids =
      from(te in @schema,
        join: j in Timekeeping.Jobs.Job, on: j.id == te.job_id,
        where: is_nil(te.end_time) and j.user_id == ^user_id,
        select: te.id
      )
      |> Repo.all()

    from(te in @schema, where: te.id in ^ids)
    |> Repo.update_all(set: [end_time: now])
  end
end
