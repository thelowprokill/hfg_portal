defmodule LoanRepayment.LoansTest do
  use LoanRepayment.DataCase

  alias LoanRepayment.{Loans, Repayments}
  alias LoanRepayment.Loans.{Loan, Repayment}

  defp d(x), do: Decimal.new(x)

  defp loan_fixture(attrs \\ %{}) do
    {:ok, loan} = Loans.create_or_update(%Loan{}, Map.merge(%{paid_to: "Bank", for: "Car", amount: "1000.00"}, attrs))
    loan
  end

  # Mirrors how the UI/API records a payment: the previous running total and the loan amount
  # ride along as virtual fields.
  defp pay(loan, amount, last_tot \\ nil) do
    attrs = %{loan_id: loan.id, paid_amount: amount, loan_amount: loan.amount}
    attrs = if last_tot, do: Map.put(attrs, :last_paid_amount, last_tot), else: attrs
    {:ok, r} = Repayments.create_or_update(%Repayment{}, attrs)
    r
  end

  describe "Loan.changeset/2" do
    test "casts amounts as Decimal and defaults active" do
      cs = Loan.changeset(%Loan{}, %{amount: "2500.50", paid_to: "Mom", for: "Tuition", description: "fall"})
      assert cs.valid?
      assert Decimal.equal?(get_change(cs, :amount), d("2500.50"))
      assert get_field(cs, :active)
      assert %{amount: ["is invalid"]} = errors_on(Loan.changeset(%Loan{}, %{amount: "a lot"}))
    end

    test "amounts are stored with 2 decimal places (Postgres rounds half away from zero)" do
      loan = loan_fixture(%{amount: "10.005"})
      assert Decimal.equal?(Loans.get(loan.id).amount, d("10.01"))
    end
  end

  describe "Loans CRUD" do
    test "create, update, get, list" do
      user = user_fixture()
      loan = loan_fixture(%{created_by_id: user.id})
      {:ok, _} = Loans.create_or_update(loan, %{description: "updated", updated_by_id: user.id})
      fetched = Loans.get(loan.id)
      assert fetched.description == "updated"
      assert fetched.created_by_id == user.id
      assert [%Loan{}] = Loans.list()
    end

    test "list/1 filters on active and searches text fields" do
      loan_fixture(%{paid_to: "Bank"})
      loan_fixture(%{paid_to: "Dad", active: false})
      assert [%Loan{paid_to: "Bank"}] = Loans.list(%{active: true})
      assert [%Loan{paid_to: "Dad"}] = Loans.list(%{search_stack: [%{field: :paid_to, val: "Da"}]})
      assert Loans.list(%{sort_stack: [%{field: :paid_to, order: :desc}]}) |> Enum.map(& &1.paid_to) == ["Dad", "Bank"]
    end

    test "activate/deactivate" do
      loan = loan_fixture()
      assert {:ok, %Loan{active: false}} = Loans.deactivate(loan.id)
      assert {:ok, %Loan{active: true}} = Loans.activate(loan)
    end

    test "a loan without repayments can be deleted" do
      loan = loan_fixture()
      assert {:ok, _} = Loans.delete(loan.id)
      assert Loans.get(loan.id) == nil
    end

    test "a loan with repayments cannot be deleted (repayment FK has no cascade)" do
      loan = loan_fixture()
      pay(loan, "10")
      assert_raise Ecto.ConstraintError, fn -> Loans.delete(loan) end
    end

    test "broadcasts on create/update/delete" do
      Loans.subscribe()
      loan = loan_fixture()
      assert_receive {[:loan, :created], %Loan{}}
      Loans.subscribe(loan.id)
      {:ok, _} = Loans.create_or_update(loan, %{for: "House"})
      assert_receive {[:loan, :updated], %Loan{for: "House"}}
      assert_receive {[:loan, :updated], %Loan{for: "House"}}
      {:ok, _} = Loans.delete(loan)
      assert_receive {[:loan, :deleted], %Loan{}}
    end
  end

  describe "Repayment.changeset/2 balance math" do
    test "first payment: total = paid, remaining = loan - paid" do
      cs = Repayment.changeset(%Repayment{}, %{paid_amount: "150.25", loan_amount: "1000"})
      assert Decimal.equal?(get_change(cs, :paid_amount_tot), d("150.25"))
      assert Decimal.equal?(get_change(cs, :remaining_balance), d("849.75"))
    end

    test "later payment: total = paid + previous total, remaining = loan - total" do
      cs = Repayment.changeset(%Repayment{}, %{paid_amount: "100", last_paid_amount: "250.50", loan_amount: "1000"})
      assert Decimal.equal?(get_change(cs, :paid_amount_tot), d("350.50"))
      assert Decimal.equal?(get_change(cs, :remaining_balance), d("649.50"))
    end

    test "decimal arithmetic is exact (no float drift)" do
      cs = Repayment.changeset(%Repayment{}, %{paid_amount: "0.1", last_paid_amount: "0.2", loan_amount: "0.3"})
      assert Decimal.equal?(get_change(cs, :paid_amount_tot), d("0.3"))
      assert Decimal.equal?(get_change(cs, :remaining_balance), d("0"))
    end

    test "paying off exactly leaves zero; overpaying goes negative (no validation)" do
      exact = Repayment.changeset(%Repayment{}, %{paid_amount: "400", last_paid_amount: "600", loan_amount: "1000"})
      assert Decimal.equal?(get_field(exact, :remaining_balance), d("0"))
      over = Repayment.changeset(%Repayment{}, %{paid_amount: "1200", loan_amount: "1000"})
      assert over.valid?
      assert Decimal.equal?(get_field(over, :remaining_balance), d("-200"))
    end

    test "numeric inputs (integer, float) are accepted" do
      cs = Repayment.changeset(%Repayment{}, %{paid_amount: 100, loan_amount: 1000.5})
      assert Decimal.equal?(get_change(cs, :remaining_balance), d("900.5"))
    end

    test "without a loan amount only the total is set" do
      cs = Repayment.changeset(%Repayment{}, %{paid_amount: "40"})
      assert Decimal.equal?(get_change(cs, :paid_amount_tot), d("40"))
      assert get_field(cs, :remaining_balance) == nil
    end

    test "without a paid amount nothing is computed" do
      cs = Repayment.changeset(%Repayment{}, %{loan_amount: "1000", last_paid_amount: "10"})
      assert get_field(cs, :paid_amount_tot) == nil
      assert get_field(cs, :remaining_balance) == nil
    end

    test "invalid amounts are reported" do
      cs = Repayment.changeset(%Repayment{}, %{paid_amount: "ten", loan_amount: "1000"})
      refute cs.valid?
      assert %{paid_amount: ["is invalid"]} = errors_on(cs)
    end

    test "total includes the previous total even without a loan amount" do
      cs = Repayment.changeset(%Repayment{}, %{paid_amount: "100", last_paid_amount: "250"})
      assert Decimal.equal?(get_field(cs, :paid_amount_tot), d("350"))
    end

    test "updating an unrelated field keeps the running total" do
      loan = loan_fixture()
      pay(loan, "250")
      second = pay(loan, "100", "250")
      assert Decimal.equal?(second.paid_amount_tot, d("350"))

      # fresh from the DB, as the API's put_repayment does: virtual fields are nil
      {:ok, updated} = Repayments.create_or_update(Repayments.get(second.id), %{updated_by_id: user_fixture().id})
      assert Decimal.equal?(updated.paid_amount_tot, d("350"))
      assert Decimal.equal?(updated.remaining_balance, d("650"))
    end
  end

  describe "Repayments" do
    test "a sequence of payments tracks total and remaining balance, persisted at 2 dp" do
      loan = loan_fixture(%{amount: "1000.00"})
      r1 = pay(loan, "333.333")
      r2 = pay(loan, "333.33", Repayments.get(r1.id).paid_amount_tot)
      r3 = pay(loan, "333.34", Repayments.get(r2.id).paid_amount_tot)

      [r1, r2, r3] = Enum.map([r1, r2, r3], &Repayments.get(&1.id))
      assert Decimal.equal?(r1.paid_amount, d("333.33"))
      assert Decimal.equal?(r1.remaining_balance, d("666.67"))
      assert Decimal.equal?(r2.paid_amount_tot, d("666.66"))
      assert Decimal.equal?(r3.paid_amount_tot, d("1000.00"))
      assert Decimal.equal?(r3.remaining_balance, d("0.00"))
    end

    test "list/1 filters by loan, newest (highest running total) first" do
      loan = loan_fixture()
      other = loan_fixture(%{paid_to: "Other"})
      a = pay(loan, "100")
      b = pay(loan, "50", "100")
      c = pay(other, "999")
      assert Repayments.list(%{loan_id: loan.id}) |> Enum.map(& &1.id) == [b.id, a.id]
      assert Repayments.list(%{}) |> Enum.map(& &1.id) == [c.id, b.id, a.id]
      assert Repayments.list(%{loan_id: loan.id, page: 1, per_page: 1}) |> Enum.map(& &1.id) == [a.id]
      assert [%Repayment{loan: %Loan{}} | _] = Repayments.list(%{loan_id: loan.id, preload: [:loan]})
    end

    test "list/1 breaks running-total ties by newest id" do
      loan = loan_fixture()
      a = pay(loan, "10")
      b = pay(loan, "10")
      assert Repayments.list(%{loan_id: loan.id}) |> Enum.map(& &1.id) == [b.id, a.id]
    end

    test "repayment_query/0 preloads each loan's highest running total" do
      loan = loan_fixture()
      none = loan_fixture(%{paid_to: "Nobody paid"})
      pay(loan, "100")
      pay(loan, "200", "100")

      [loan, none] = Loans.preload([loan, none], %{preload: [repayment: Repayments.repayment_query()]})
      assert Decimal.equal?(loan.repayment.paid_amount_tot, d("300"))
      assert none.repayment == nil
    end

    test "repayment rejects an unknown loan (FK)" do
      assert_raise Ecto.ConstraintError, fn ->
        Repayments.create_or_update(%Repayment{}, %{loan_id: -1, paid_amount: "1"})
      end
    end

    test "deleting a repayment" do
      loan = loan_fixture()
      r = pay(loan, "5")
      assert {:ok, _} = Repayments.delete(r.id)
      assert Repayments.list(%{loan_id: loan.id}) == []
    end

    test "broadcasts on create/update/delete" do
      loan = loan_fixture()
      Repayments.subscribe()
      r = pay(loan, "5")
      assert_receive {[:repayment, :created], %Repayment{}}
      {:ok, _} = Repayments.create_or_update(r, %{paid_amount: "6", loan_amount: loan.amount})
      assert_receive {[:repayment, :updated], %Repayment{}}
      {:ok, _} = Repayments.delete(r)
      assert_receive {[:repayment, :deleted], %Repayment{}}
    end
  end
end
