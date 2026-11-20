defmodule Timekeeping.TimeEntriesTest do
  use Timekeeping.DataCase

  alias Timekeeping.{Jobs, TimeEntries}
  alias Timekeeping.TimeEntries.TimeEntry

  defp job_fixture(user_id) do
    {:ok, job} = Jobs.new() |> Jobs.create_or_update(%{user_id: user_id, name: "Job #{System.unique_integer([:positive])}"})
    job
  end

  defp entry(job, start_time, end_time \\ nil) do
    {:ok, e} = TimeEntries.new() |> TimeEntries.create_or_update(%{job_id: job.id, start_time: start_time, end_time: end_time})
    e
  end

  describe "changeset" do
    test "requires job_id and start_time" do
      assert %{job_id: ["can't be blank"], start_time: ["can't be blank"]} = errors_on(TimeEntry.changeset(%TimeEntry{}, %{}))
    end

    test "end_time must not be before start_time" do
      cs = TimeEntry.changeset(%TimeEntry{}, %{job_id: 1, start_time: ~U[2026-01-01 10:00:00Z], end_time: ~U[2026-01-01 09:59:59Z]})
      assert %{end_time: ["must be after the start time"]} = errors_on(cs)
    end

    test "an open entry, or a zero-length one, is valid" do
      assert TimeEntry.changeset(%TimeEntry{}, %{job_id: 1, start_time: ~U[2026-01-01 10:00:00Z]}).valid?
      assert TimeEntry.changeset(%TimeEntry{}, %{job_id: 1, start_time: ~U[2026-01-01 10:00:00Z], end_time: ~U[2026-01-01 10:00:00Z]}).valid?
    end

    test "the end check uses the stored start when only end_time changes" do
      e = %TimeEntry{job_id: 1, start_time: ~U[2026-01-01 10:00:00Z]}
      refute TimeEntry.changeset(e, %{end_time: ~U[2026-01-01 09:00:00Z]}).valid?
      assert TimeEntry.changeset(e, %{end_time: ~U[2026-01-01 11:00:00Z]}).valid?
    end

    test "a missing job is rejected by the database" do
      assert_raise Ecto.ConstraintError, fn ->
        TimeEntries.new() |> TimeEntries.create_or_update(%{job_id: -1, start_time: ~U[2026-01-01 10:00:00Z]})
      end
    end
  end

  test "list_for_job/1 returns only that job's entries, newest first" do
    job = job_fixture(1)
    other = job_fixture(1)
    old = entry(job, ~U[2026-01-01 08:00:00Z], ~U[2026-01-01 09:00:00Z])
    new = entry(job, ~U[2026-01-02 08:00:00Z])
    _ = entry(other, ~U[2026-01-03 08:00:00Z])

    assert Enum.map(TimeEntries.list_for_job(job.id), & &1.id) == [new.id, old.id]
    assert TimeEntries.list_for_job(-1) == []
  end

  test "get_open_for_job/1 finds the running entry only" do
    job = job_fixture(1)
    _ = entry(job, ~U[2026-01-01 08:00:00Z], ~U[2026-01-01 09:00:00Z])
    assert TimeEntries.get_open_for_job(job.id) == nil

    open = entry(job, ~U[2026-01-01 10:00:00Z])
    assert TimeEntries.get_open_for_job(job.id).id == open.id
  end

  test "open_job_starts/0 maps every running job to its start" do
    j1 = job_fixture(1)
    j2 = job_fixture(2)
    j3 = job_fixture(1)
    _ = entry(j1, ~U[2026-01-01 08:00:00Z])
    _ = entry(j2, ~U[2026-01-01 09:00:00Z])
    _ = entry(j3, ~U[2026-01-01 07:00:00Z], ~U[2026-01-01 08:00:00Z])

    assert TimeEntries.open_job_starts() == %{j1.id => ~U[2026-01-01 08:00:00Z], j2.id => ~U[2026-01-01 09:00:00Z]}
  end

  describe "total_seconds_by_job/1" do
    test "sums completed entries per job, ignoring running ones and other jobs" do
      j1 = job_fixture(1)
      j2 = job_fixture(1)
      j3 = job_fixture(1)
      skipped = job_fixture(1)
      _ = entry(j1, ~U[2026-01-01 08:00:00Z], ~U[2026-01-01 09:30:00Z])
      _ = entry(j1, ~U[2026-01-02 08:00:00Z], ~U[2026-01-02 08:00:45Z])
      _ = entry(j1, ~U[2026-01-03 08:00:00Z])
      _ = entry(j2, ~U[2026-01-01 23:00:00Z], ~U[2026-01-02 01:00:00Z])
      _ = entry(j3, ~U[2026-01-01 08:00:00Z])
      _ = entry(skipped, ~U[2026-01-01 08:00:00Z], ~U[2026-01-01 09:00:00Z])

      totals = TimeEntries.total_seconds_by_job([j1.id, j2.id, j3.id])
      assert totals == %{j1.id => 5445, j2.id => 7200}
    end

    test "no jobs, no totals" do
      assert TimeEntries.total_seconds_by_job([]) == %{}
    end
  end

  describe "start_now/2" do
    test "opens an entry now, truncated to the second, and broadcasts it" do
      job = job_fixture(1)
      TimeEntries.subscribe()
      before = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, %TimeEntry{end_time: nil} = e} = TimeEntries.start_now(job.id, 1)
      assert e.start_time.microsecond == {0, 0}
      assert DateTime.compare(e.start_time, before) in [:gt, :eq]
      assert_receive {[:time_entry, :created], %TimeEntry{id: id}}
      assert id == e.id
    end

    test "stops the user's other running timers, across jobs, but not other users'" do
      mine = job_fixture(1)
      also_mine = job_fixture(1)
      theirs = job_fixture(2)
      running_mine = entry(mine, ~U[2026-01-01 08:00:00Z])
      running_theirs = entry(theirs, ~U[2026-01-01 08:00:00Z])
      done = entry(mine, ~U[2025-01-01 08:00:00Z], ~U[2025-01-01 09:00:00Z])

      {:ok, new} = TimeEntries.start_now(also_mine.id, 1)

      stopped = TimeEntries.get(running_mine.id)
      assert stopped.end_time == new.start_time
      assert TimeEntries.get(running_theirs.id).end_time == nil
      assert TimeEntries.get(done.id).end_time == ~U[2025-01-01 09:00:00Z]
      assert TimeEntries.open_job_starts() |> Map.keys() |> Enum.sort() == Enum.sort([also_mine.id, theirs.id])
    end

    test "restarting the same job leaves exactly one open entry" do
      job = job_fixture(1)
      _ = entry(job, ~U[2026-01-01 08:00:00Z])
      {:ok, new} = TimeEntries.start_now(job.id, 1)
      assert TimeEntries.get_open_for_job(job.id).id == new.id
    end
  end

  test "stop_now/1 closes the entry now and broadcasts an update" do
    job = job_fixture(1)
    e = entry(job, ~U[2026-01-01 08:00:00Z])
    TimeEntries.subscribe(e.id)

    assert {:ok, %TimeEntry{end_time: %DateTime{} = end_time}} = TimeEntries.stop_now(e.id)
    assert end_time.microsecond == {0, 0}
    assert_receive {[:time_entry, :updated], %TimeEntry{id: id}}
    assert id == e.id
    assert TimeEntries.get_open_for_job(job.id) == nil
  end
end
