defmodule Timekeeping.JobsTest do
  use Timekeeping.DataCase

  alias Timekeeping.{Jobs, TimeEntries}
  alias Timekeeping.Jobs.Job
  alias HfgPortal.Helpers.{Search, Sort}

  defp job_fixture(attrs \\ %{}) do
    {:ok, job} = Jobs.new() |> Jobs.create_or_update(Enum.into(attrs, %{user_id: 1, name: "Job #{System.unique_integer([:positive])}"}))
    job
  end

  describe "changeset" do
    test "requires user_id and name" do
      assert {:error, cs} = Jobs.new() |> Jobs.create_or_update(%{})
      assert %{user_id: ["can't be blank"], name: ["can't be blank"]} = errors_on(cs)
    end

    test "defaults to active and keeps the hourly rate as a decimal" do
      job = job_fixture(%{client: "Acme", hourly_rate: "42.50"})
      assert job.active
      assert Decimal.equal?(job.hourly_rate, Decimal.new("42.50"))
      assert %Job{client: "Acme"} = Jobs.get(job.id)
    end

    test "new_changeset/1 builds a changeset for a new job" do
      cs = Jobs.new_changeset(%{user_id: 7})
      assert cs.data.id == nil
      refute cs.valid?
      assert %{name: ["can't be blank"]} = errors_on(cs)
    end
  end

  describe "create_or_update/2 broadcasts" do
    test "created on insert, updated on update, deleted on delete — to the topic and the item topic" do
      Jobs.subscribe()
      job = job_fixture(%{name: "Fence"})
      assert_receive {[:job, :created], %Job{id: id, name: "Fence"}}
      assert id == job.id

      Jobs.subscribe(job.id)
      {:ok, _} = Jobs.create_or_update(job, %{name: "Gate"})
      assert_receive {[:job, :updated], %Job{name: "Gate"}}
      assert_receive {[:job, :updated], %Job{name: "Gate"}}

      {:ok, _} = Jobs.delete(job.id)
      assert_receive {[:job, :deleted], %Job{id: ^id}}
      assert Jobs.get(id) == nil
    end

    test "an invalid change broadcasts nothing" do
      Jobs.subscribe()
      assert {:error, _} = Jobs.new() |> Jobs.create_or_update(%{name: "no user"})
      refute_receive {[:job, _], _}
    end
  end

  describe "list/1" do
    setup do
      a = job_fixture(%{name: "Alpha", client: "Zed"})
      b = job_fixture(%{name: "Bravo", client: "Acme", active: false})
      c = job_fixture(%{name: "Charlie", client: "Acme"})
      %{a: a, b: b, c: c}
    end

    test "returns all jobs ordered by name", %{a: a, b: b, c: c} do
      assert Enum.map(Jobs.list(%{}), & &1.id) == [a.id, b.id, c.id]
      assert Enum.map(Jobs.list(), & &1.id) == [a.id, b.id, c.id]
    end

    test "search_stack filters by substring and ignores unknown fields and blank values", %{c: c} do
      assert [^c] = Jobs.list(%{search_stack: [%Search{field: :name, val: "arl"}]})
      assert length(Jobs.list(%{search_stack: [%Search{field: :name, val: ""}]})) == 3
      assert length(Jobs.list(%{search_stack: [%Search{field: :nope, val: "x"}]})) == 3
    end

    test "search_stack on timestamps keeps rows at or after the value" do
      assert length(Jobs.list(%{search_stack: [%Search{field: :inserted_at, val: ~N[2000-01-01 00:00:00]}]})) == 3
      assert Jobs.list(%{search_stack: [%Search{field: :inserted_at, val: ~N[2999-01-01 00:00:00]}]}) == []
    end

    test "sort_stack sorts first, name breaks ties", %{a: a, b: b, c: c} do
      assert Enum.map(Jobs.list(%{sort_stack: [%Sort{field: :client, order: :asc}]}), & &1.id) == [b.id, c.id, a.id]
      assert Enum.map(Jobs.list(%{sort_stack: [%Sort{field: :client, order: :desc}]}), & &1.id) == [a.id, b.id, c.id]
    end

    test "paginates zero-based, string params accepted", %{a: a, b: b, c: c} do
      assert Enum.map(Jobs.list(%{page: 0, per_page: 2}), & &1.id) == [a.id, b.id]
      assert Enum.map(Jobs.list(%{page: 1, per_page: 2}), & &1.id) == [c.id]
      assert Enum.map(Jobs.list(%{page: "1", per_page: "2"}), & &1.id) == [c.id]
    end

    test "active filter", %{b: b} do
      assert [^b] = Jobs.list(%{active: false})
      assert length(Jobs.list(%{active: true})) == 2
    end

    test "preloads time entries", %{a: a} do
      {:ok, _} = TimeEntries.new() |> TimeEntries.create_or_update(%{job_id: a.id, start_time: ~U[2026-01-01 08:00:00Z]})
      [loaded | _] = Jobs.list(%{preload: [:time_entries]})
      assert [%{job_id: job_id}] = loaded.time_entries
      assert job_id == a.id
    end
  end

  describe "activate/deactivate" do
    test "flip the active flag by struct or id and broadcast an update" do
      job = job_fixture()
      Jobs.subscribe()
      assert {:ok, %Job{active: false}} = Jobs.deactivate(job)
      assert_receive {[:job, :updated], %Job{active: false}}
      assert {:ok, %Job{active: true}} = Jobs.activate(job.id)
      assert Jobs.get(job.id).active
    end
  end

  test "deleting a job deletes its time entries" do
    job = job_fixture()
    {:ok, entry} = TimeEntries.new() |> TimeEntries.create_or_update(%{job_id: job.id, start_time: ~U[2026-01-01 08:00:00Z]})
    {:ok, _} = Jobs.delete(job)
    assert TimeEntries.get(entry.id) == nil
  end
end
