defmodule HfgPortalWeb.Apis.LoanRepaymentApiTest do
  use HfgPortalWeb.ApiCase

  alias LoanRepayment.{Loans, Repayments}

  @routes [
    {"loan_repayment:loans", "GET", "loans", :view},
    {"loan_repayment:loans", "GET", "loan", :view},
    {"loan_repayment:loans", "PUT", "loan", :admin},
    {"loan_repayment:loans", "DELETE", "loan", :admin},
    {"loan_repayment:repayments", "GET", "repayments", :view},
    {"loan_repayment:repayments", "GET", "repayment", :view},
    {"loan_repayment:repayments", "PUT", "repayment", :edit},
    {"loan_repayment:repayments", "DELETE", "repayment", :admin}
  ]

  @below %{view: [nil, "None"], edit: [nil, "None", "View"], admin: [nil, "None", "View", "Edit"]}

  defp jwt(nil), do: token(api_user())
  defp jwt(role), do: token(api_user(%{loan_repayment: role}))

  defp call(conn, role, method, scope, route, query \\ %{}),
    do: api(conn, method, jwt(role), Map.merge(%{"scope" => "loan_repayment:" <> scope, "route" => route}, query))

  defp dec_eq(s, expected), do: Decimal.equal?(Decimal.new(s), Decimal.new(expected))

  defp loan(attrs \\ %{}) do
    {:ok, l} = Loans.create_or_update(Loans.new(), Map.merge(%{paid_to: "Bank", for: "Car", amount: "1000"}, attrs))
    l
  end

  defp repay(loan, paid, last \\ nil) do
    attrs = %{loan_id: loan.id, paid_amount: paid, loan_amount: loan.amount}
    attrs = if last, do: Map.put(attrs, :last_paid_amount, last), else: attrs
    {:ok, r} = Repayments.create_or_update(Repayments.new(), attrs)
    r
  end

  test "authorization: roles below the required one are refused", %{conn: conn} do
    for {scope, method, route, required} <- @routes, role <- @below[required] do
      assert %{"error" => "Unauthorized"} = conn |> api(method, jwt(role), %{"scope" => scope, "route" => route, "id" => "1"}) |> json_response(401),
             "#{method} #{scope}/#{route} let #{inspect(role)} through"
    end

    assert %{"error" => "Route not found"} = conn |> call("Admin", "PUT", "loans", "loans") |> json_response(404)
  end

  describe "loans" do
    test "list and get include the total repaid and remaining balance", %{conn: conn} do
      l = loan()
      repay(l, "100")
      repay(l, "50", "100")
      bare = loan(%{paid_to: "Mom", amount: "40"})

      loans = conn |> call("View", "GET", "loans", "loans") |> data()
      assert %{"paid_to" => "Bank", "for" => "Car", "active" => true} = got = Enum.find(loans, &(&1["id"] == l.id))
      assert dec_eq(got["paid_amount_tot"], "150")
      assert dec_eq(got["remaining_balance"], "850")
      assert %{"paid_amount_tot" => nil} = mom = Enum.find(loans, &(&1["id"] == bare.id))
      assert dec_eq(mom["remaining_balance"], "40")

      assert %{"id" => id} = one = conn |> call("View", "GET", "loans", "loan", %{"id" => "#{l.id}"}) |> data()
      assert id == l.id
      assert dec_eq(one["remaining_balance"], "850")
    end

    test "DELETE (Admin) removes a loan", %{conn: conn} do
      l = loan()
      assert conn |> call("Admin", "DELETE", "loans", "loan", %{"id" => "#{l.id}"}) |> data() == nil
      assert Loans.get(l.id) == nil
    end

    test "PUT (Admin) creates and updates a loan", %{conn: conn} do
      assert %{"id" => id, "paid_to" => "Bank", "amount" => amount, "remaining_balance" => rem} =
               conn |> call("Admin", "PUT", "loans", "loan", %{"paid_to" => "Bank", "for" => "Car", "amount" => "300"}) |> data()

      assert dec_eq(amount, "300") and dec_eq(rem, "300")
      assert %{"id" => ^id, "active" => false} = conn |> call("Admin", "PUT", "loans", "loan", %{"id" => "#{id}", "active" => "false"}) |> data()
    end
  end

  describe "repayments" do
    test "PUT (Edit) records a repayment and computes running totals", %{conn: conn} do
      l = loan()

      q = %{"loan_id" => "#{l.id}", "paid_amount" => "200", "last_paid_amount" => "100", "loan_amount" => "1000"}
      assert %{"id" => id, "loan_id" => lid, "paid_amount_tot" => tot, "remaining_balance" => rem, "inserted_at" => _} =
               conn |> call("Edit", "PUT", "repayments", "repayment", q) |> data()

      assert lid == l.id
      assert dec_eq(tot, "300") and dec_eq(rem, "700")

      assert %{"id" => ^id, "paid_amount" => paid} = conn |> call("Edit", "PUT", "repayments", "repayment", %{"id" => "#{id}", "paid_amount" => "250"}) |> data()
      assert dec_eq(paid, "250")
    end

    test "list (optionally by loan), get and delete", %{conn: conn} do
      l = loan()
      r1 = repay(l, "100")
      r2 = repay(l, "50", "100")
      other = repay(loan(), "1")

      ids = fn q -> conn |> call("View", "GET", "repayments", "repayments", q) |> data() |> Enum.map(& &1["id"]) end
      assert ids.(%{"loan_id" => "#{l.id}"}) == [r2.id, r1.id]
      assert Enum.sort(ids.(%{})) == Enum.sort([r1.id, r2.id, other.id])

      assert %{"id" => id} = conn |> call("View", "GET", "repayments", "repayment", %{"id" => "#{r1.id}"}) |> data()
      assert id == r1.id

      assert conn |> call("Admin", "DELETE", "repayments", "repayment", %{"id" => "#{r1.id}"}) |> data() == nil
      assert Repayments.get(r1.id) == nil
    end
  end
end
