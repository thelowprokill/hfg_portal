defmodule TaskAutomationController.QueuedItemsTest do
  use TaskAutomationController.DataCase

  alias TaskAutomationController.QueuedItems
  alias HfgPortal.Helpers.{Search, Sort}

  defp ids(items), do: Enum.map(items, & &1.id)

  setup do
    job = job_fixture()
    items =
      for status <- ~w(unassigned waiting running completed failed),
          into: %{},
          do: {status, queue_fixture(%{job_id: job.id, status: status})}

    %{job: job, items: items}
  end

  test "complete: false lists only work still to do", %{items: items} do
    expected = Enum.map(~w(unassigned waiting running), &items[&1].id) |> Enum.sort()
    assert QueuedItems.list(%{complete: false}) |> ids() |> Enum.sort() == expected
  end

  test "complete: true lists finished work, newest first", %{items: items, job: job} do
    newer = queue_fixture(%{job_id: job.id, status: "completed"})
    assert ids(QueuedItems.list(%{complete: true})) == [newer.id, items["failed"].id, items["completed"].id]
  end

  test "no complete option lists everything" do
    assert length(QueuedItems.list(%{})) == 5
  end

  test "sorting by machine or job sorts by their names, not ids", %{job: job} do
    HfgPortal.Repo.delete_all(Queue)
    zeta  = machine_fixture(%{name: "Zeta"})
    alpha = machine_fixture(%{name: "Alpha"})
    q1 = queue_fixture(%{job_id: job.id, machine_id: zeta.id})
    q2 = queue_fixture(%{job_id: job.id, machine_id: alpha.id})
    q3 = queue_fixture(%{job_id: job.id})

    # unassigned machine (NULL name) sorts last ascending in Postgres
    assert ids(QueuedItems.list(%{sort_stack: [%Sort{field: :machine_id, order: :asc}]})) == [q2.id, q1.id, q3.id]

    HfgPortal.Repo.delete_all(Queue)
    zjob = job_fixture(%{name: "zz"})
    ajob = job_fixture(%{name: "aa"})
    qz = queue_fixture(%{job_id: zjob.id})
    qa = queue_fixture(%{job_id: ajob.id})
    assert ids(QueuedItems.list(%{sort_stack: [%Sort{field: :job_id, order: :asc}]})) == [qa.id, qz.id]
    assert ids(QueuedItems.list(%{sort_stack: [%Sort{field: :job_id, order: :desc}]})) == [qz.id, qa.id]
  end

  test "sorting by a plain field and ignoring unknown fields", %{items: items} do
    sorted = QueuedItems.list(%{sort_stack: [%Sort{field: :status, order: :asc}, %Sort{field: :bogus, order: :asc}]})
    assert ids(sorted) == Enum.map(~w(completed failed running unassigned waiting), &items[&1].id)
  end

  test "search, active filter, pagination and preload", %{items: items, job: job} do
    assert ids(QueuedItems.list(%{search_stack: [%Search{field: :status, val: "run"}]})) == [items["running"].id]

    {:ok, _} = QueuedItems.deactivate(items["waiting"])
    refute items["waiting"].id in ids(QueuedItems.list(%{active: true}))
    assert ids(QueuedItems.list(%{active: false})) == [items["waiting"].id]

    page = QueuedItems.list(%{sort_stack: [%Sort{field: :id, order: :asc}], page: 1, per_page: 2})
    assert ids(page) == [items["running"].id, items["completed"].id]

    assert [%Queue{job: %Job{id: jid}, machine: nil} | _] = QueuedItems.list(%{preload: [:job, :machine]})
    assert jid == job.id
  end

  test "records run times and the requesting user" do
    user = user_fixture()
    started = ~N[2026-01-01 10:00:00]
    q = queue_fixture(%{status: "completed", type: "scheduled", user_id: user.id,
                        started_at: started, completed_at: NaiveDateTime.add(started, 90), runtime: 90})
    q = QueuedItems.get(q.id) |> QueuedItems.preload(%{preload: [:user]})
    assert q.user.username == user.username
    assert NaiveDateTime.diff(q.completed_at, q.started_at) == q.runtime
  end

  test "update/0 pings subscribers so they reload the queue" do
    QueuedItems.subscribe()
    QueuedItems.subscribe(1)
    assert {:ok, %{id: 1}} = QueuedItems.update()
    assert_receive {[:queued_item, :updated], %{id: 1}}
    assert_receive {[:queued_item, :updated], %{id: 1}}
  end

  test "queue items go when their job or machine is deleted", %{job: job, items: items} do
    m = machine_fixture()
    q = queue_fixture(%{machine_id: m.id})
    {:ok, _} = TaskAutomationController.Machines.delete(m)
    assert QueuedItems.get(q.id) == nil

    {:ok, _} = TaskAutomationController.Jobs.delete(job)
    assert QueuedItems.get(items["running"].id) == nil
  end
end
