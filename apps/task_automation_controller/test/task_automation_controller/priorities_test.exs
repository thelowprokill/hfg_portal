defmodule TaskAutomationController.PrioritiesTest do
  use TaskAutomationController.DataCase

  alias TaskAutomationController.Priorities
  alias HfgPortal.Helpers.Sort

  test "name is required" do
    assert %{name: ["can't be blank"]} = errors_on(Priority.changeset(%Priority{}, %{order: 1}))
  end

  test "an explicit order is kept" do
    assert Priority.changeset(%Priority{}, %{name: "x", order: 42}).changes.order == 42
  end

  # set_order reads through TaskAutomationController.Repo, so seed through it as well
  test "a missing order becomes one past the current maximum" do
    assert Priority.changeset(%Priority{}, %{name: "first"}).changes.order == 1

    TaskAutomationController.Repo.insert!(%Priority{name: "a", order: 3})
    TaskAutomationController.Repo.insert!(%Priority{name: "b", order: 7})
    assert Priority.changeset(%Priority{}, %{name: "next"}).changes.order == 8
  end

  test "editing a priority does not renumber it" do
    TaskAutomationController.Repo.insert!(%Priority{name: "a", order: 9})
    assert Priority.changeset(%Priority{name: "x", order: 2}, %{name: "y"}) |> get_field(:order) == 2
  end

  test "list puts the highest order first unless a sort is given" do
    low  = priority_fixture(%{name: "Low", order: 1})
    high = priority_fixture(%{name: "High", order: 3})
    mid  = priority_fixture(%{name: "Mid", order: 2, active: false})

    assert Enum.map(Priorities.list(%{}), & &1.id) == [high.id, mid.id, low.id]
    assert Enum.map(Priorities.list(), & &1.id) == [high.id, mid.id, low.id]
    assert Enum.map(Priorities.list(%{active: true}), & &1.id) == [high.id, low.id]
    assert Enum.map(Priorities.list(%{sort_stack: [%Sort{field: :name, order: :asc}]}), & &1.name) == ["High", "Low", "Mid"]
    assert Enum.map(Priorities.list(%{page: 0, per_page: 1}), & &1.id) == [high.id]
  end

  test "move_up swaps order with the next lower priority and broadcasts both" do
    a = priority_fixture(%{order: 1})
    b = priority_fixture(%{order: 5})
    c = priority_fixture(%{order: 9})
    Priorities.subscribe()

    assert {:ok, _} = Priorities.move_up(c.id)

    assert Priorities.get(c.id).order == 5
    assert Priorities.get(b.id).order == 9
    assert Priorities.get(a.id).order == 1
    assert_receive {[:priority, :updated], %Priority{order: 5}}
    assert_receive {[:priority, :updated], %Priority{order: 9}}
  end

  test "move_up on the lowest priority is a no-op" do
    a = priority_fixture(%{order: 1})
    priority_fixture(%{order: 2})
    Priorities.move_up(a.id)
    assert Priorities.get(a.id).order == 1
  end

  test "deleting a priority deletes its jobs" do
    p = priority_fixture()
    job = job_fixture(%{priority_id: p.id})
    {:ok, _} = Priorities.delete(p)
    assert TaskAutomationController.Jobs.get(job.id) == nil
  end
end
