defmodule TaskAutomationController.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use TaskAutomationController.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias TaskAutomationController.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import TaskAutomationController.DataCase
      alias TaskAutomationController.Jobs.{Job, Machine, Priority, Queue, Schedule}
      alias TaskAutomationController.Users.{Role, RoleJob, UserRole}
    end
  end

  setup tags do
    TaskAutomationController.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    # The contexts read and write through HfgPortal.Repo (DefaultCrud); only Priority.set_order uses this app's Repo
    for repo <- [TaskAutomationController.Repo, HfgPortal.Repo] do
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(repo, shared: not tags[:async])
      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    end
  end

  @doc "Inserts a portal user (hfg_portal users table), which this app maps as Users.User."
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      HfgPortal.Accounts.create_or_update(%HfgPortal.Accounts.User{}, Enum.into(attrs, %{
        username:         "user#{System.unique_integer([:positive])}",
        password:         "hello world!",
        password_confirm: "hello world!",
        active:           true
      }))
    user
  end

  @doc "Creates a record through a context's create_or_update, raising on failure."
  def create!(context, attrs) do
    {:ok, item} = context.create_or_update(context.new(), Enum.into(attrs, %{}))
    item
  end

  def priority_fixture(attrs \\ %{}),
    do: create!(TaskAutomationController.Priorities, Enum.into(attrs, %{name: "Normal", order: System.unique_integer([:positive])}))

  def job_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "job#{System.unique_integer([:positive])}", address: "http://x/run"})
    create!(TaskAutomationController.Jobs, Map.put_new_lazy(attrs, :priority_id, fn -> priority_fixture().id end))
  end

  def machine_fixture(attrs \\ %{}),
    do: create!(TaskAutomationController.Machines, Enum.into(attrs, %{name: "machine#{System.unique_integer([:positive])}", address: "10.0.0.1"}))

  # Role.changeset does not cast :admin, so admin roles go straight into the repo
  def role_fixture(attrs \\ %{}),
    do: HfgPortal.Repo.insert!(struct(TaskAutomationController.Users.Role, Enum.into(attrs, %{name: "role#{System.unique_integer([:positive])}"})))

  def user_role_fixture(user, role),
    do: create!(TaskAutomationController.UserRoles, %{user_id: user.id, role_id: role.id, active: true})

  def role_job_fixture(role, job),
    do: create!(TaskAutomationController.RoleJobs, %{role_id: role.id, job_id: job.id})

  def queue_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{status: "unassigned", type: "user"})
    create!(TaskAutomationController.QueuedItems, Map.put_new_lazy(attrs, :job_id, fn -> job_fixture().id end))
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
