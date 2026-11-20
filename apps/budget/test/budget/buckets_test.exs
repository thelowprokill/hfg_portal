defmodule Budget.BucketsTest do
  use Budget.DataCase

  alias Budget.Buckets
  alias Budget.Buckets.Bucket

  defp cs(attrs), do: Bucket.changeset(%Bucket{}, Enum.into(attrs, %{user_id: 1, name: "B"}))

  describe "changeset" do
    test "requires user and name, defaults to a normal bucket with zero balance" do
      assert %{user_id: ["can't be blank"], name: ["can't be blank"]} =
               errors_on(Bucket.changeset(%Bucket{}, %{}))

      bucket = bucket_fixture()
      assert bucket.type == "normal"
      assert dec_eq?(Buckets.get(bucket.id).balance, 0)
    end

    test "type must be normal, sinking_fund or emergency_fund" do
      for t <- ~w(normal sinking_fund emergency_fund), do: assert(cs(type: t).valid?)
      assert %{type: ["is invalid"]} = errors_on(cs(type: "savings"))
    end

    test "a sinking fund needs both a contribution and a max balance, or neither" do
      assert cs(type: "sinking_fund").valid?
      assert cs(type: "sinking_fund", monthly_contribution: 10, max_balance: 100).valid?

      assert %{max_balance: ["is required when monthly_contribution is set"]} =
               errors_on(cs(type: "sinking_fund", monthly_contribution: 10))

      assert %{monthly_contribution: ["is required when max_balance is set"]} =
               errors_on(cs(type: "sinking_fund", max_balance: 100))
    end

    test "the pairing rule only applies to sinking funds" do
      assert cs(type: "emergency_fund", monthly_contribution: 10).valid?
      assert cs(type: "normal", max_balance: 100).valid?
    end

    test "the pairing rule considers values already on the bucket" do
      bucket = bucket_fixture(type: "sinking_fund", monthly_contribution: 10, max_balance: 100)

      assert %{monthly_contribution: [_]} =
               errors_on(Bucket.changeset(bucket, %{monthly_contribution: nil}))

      assert Bucket.changeset(bucket, %{monthly_contribution: nil, max_balance: nil}).valid?
    end

    test "invalid attrs come back as an error from create_or_update" do
      assert {:error, %Ecto.Changeset{}} = Buckets.create_or_update(Buckets.new(), %{name: "x"})
    end
  end

  describe "fund lists" do
    test "list_all_sinking_funds and list_all_emergency_funds are filtered by type and sorted by name" do
      bucket_fixture(name: "Zeta", type: "sinking_fund")
      bucket_fixture(name: "Alpha", type: "sinking_fund")
      bucket_fixture(name: "Rainy", type: "emergency_fund")
      bucket_fixture(name: "Food")

      assert Enum.map(Buckets.list_all_sinking_funds(), & &1.name) == ["Alpha", "Zeta"]
      assert Enum.map(Buckets.list_all_emergency_funds(), & &1.name) == ["Rainy"]
    end

    test "empty when there are none" do
      bucket_fixture()
      assert Buckets.list_all_sinking_funds() == []
      assert Buckets.list_all_emergency_funds() == []
    end
  end

  describe "list/1" do
    setup do
      for {name, budget} <- [{"Car", 50}, {"Abc", 300}, {"Bills", 200}, {"Dog", 100}] do
        bucket_fixture(name: name, monthly_budget: budget)
      end

      :ok
    end

    test "orders by name and paginates (zero-based pages)" do
      assert Enum.map(Buckets.list(%{}), & &1.name) == ["Abc", "Bills", "Car", "Dog"]
      assert Enum.map(Buckets.list(%{page: 0, per_page: 3}), & &1.name) == ["Abc", "Bills", "Car"]
      assert Enum.map(Buckets.list(%{page: 1, per_page: 3}), & &1.name) == ["Dog"]
      assert Buckets.list(%{page: 2, per_page: 3}) == []
    end

    test "sort_stack takes precedence over the name order" do
      sorted = Buckets.list(%{sort_stack: [%{field: :monthly_budget, order: :desc}]})
      assert Enum.map(sorted, & &1.name) == ["Abc", "Bills", "Dog", "Car"]
    end

    test "search_stack matches substrings, and an empty value matches everything" do
      assert [%{name: "Bills"}] = Buckets.list(%{search_stack: [%{field: :name, val: "ill"}]})
      assert length(Buckets.list(%{search_stack: [%{field: :name, val: ""}]})) == 4
    end

    test "preloads associations" do
      [b | _] = Buckets.list(%{preload: [:transactions, :scheduled_expenses]})
      assert b.transactions == []
      assert b.scheduled_expenses == []
    end
  end

  test "create, update and delete broadcast" do
    Buckets.subscribe()
    bucket = bucket_fixture(name: "Pets")
    assert_receive {[:bucket, :created], %Bucket{name: "Pets"}}

    {:ok, _} = Buckets.create_or_update(bucket, %{name: "Pet"})
    assert_receive {[:bucket, :updated], %Bucket{name: "Pet"}}
    assert Buckets.get(bucket.id).name == "Pet"

    {:ok, _} = Buckets.delete(bucket.id)
    assert_receive {[:bucket, :deleted], _}
    assert Buckets.get(bucket.id) == nil
  end
end
