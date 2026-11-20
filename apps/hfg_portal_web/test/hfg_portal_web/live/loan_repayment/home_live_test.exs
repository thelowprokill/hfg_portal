defmodule HfgPortalWeb.LoanRepayment.HomeLiveTest do
  use HfgPortalWeb.ConnCase

  import Phoenix.LiveViewTest
  import HfgPortalWeb.LiveFixtures2

  alias LoanRepayment.{Loans, Repayments, UserRoles}

  @page "loan_repayment,home"

  defp loan_fixture(attrs \\ %{}) do
    {:ok, loan} =
      Loans.create_or_update(Loans.new(), Enum.into(attrs, %{paid_to: "Lender #{System.unique_integer([:positive])}", for: "Stuff", amount: Decimal.new(100)}))

    loan
  end

  # what the repayment form sends: the payment plus the previous total and the loan amount
  defp repayment_fixture(loan, paid, last_total) do
    {:ok, r} =
      Repayments.create_or_update(Repayments.new(), %{
        loan_id: loan.id, paid_amount: Decimal.new(paid), last_paid_amount: Decimal.new(last_total), loan_amount: loan.amount
      })

    r
  end

  defp loan_rows(page), do: count(page, ~s(tr[phx-click="repayment"]))

  setup %{conn: conn} do
    user = user_with_role(UserRoles, "Edit")
    %{conn: log_in_user(conn, user), user: user}
  end

  describe "authorization" do
    test "View, Edit and Admin roles open the page", %{conn: conn} do
      for role <- ~w(View Edit Admin) do
        conn = log_in_user(conn, user_with_role(UserRoles, role))
        assert page_module(conn, @page) == HfgPortalWeb.LoanRepayment.Home.HomeLive
      end
    end

    test "None or no role gets the portal home", %{conn: conn} do
      for user <- [user_with_role(UserRoles, "None"), HfgPortal.AccountsFixtures.user_fixture()] do
        assert page_module(log_in_user(conn, user), @page) == HfgPortalWeb.Home.HomeLive
      end
    end

    test "the Admin role opens the Users page", %{conn: conn} do
      conn = log_in_user(conn, user_with_role(UserRoles, "Admin"))
      assert page_module(conn, "loan_repayment,users") == HfgPortalWeb.LoanRepayment.Users.UsersLive
    end

    test "a View user can't change loans", %{conn: conn} do
      loan = loan_fixture()
      {_view, page} = open_page(log_in_user(conn, user_with_role(UserRoles, "View")), @page)

      refute has_element?(page, ~s(button[phx-click="add_new"]))
      refute has_element?(page, ~s(button[phx-click="edit"]))
      render_click(page, "delete", %{"id" => "#{loan.id}"})
      assert Loans.get(loan.id)
    end
  end

  describe "loan list" do
    test "shows loans with what's been paid; delete only while nothing is", %{conn: conn} do
      unpaid = loan_fixture(%{paid_to: "Bank", for: "Car", description: "auto loan", amount: Decimal.new(5000)})
      paid = loan_fixture(%{paid_to: "Mom"})
      repayment_fixture(paid, 30, 0)
      repayment_fixture(paid, 20, 30)

      {_view, page} = open_page(conn, @page)
      html = render(page)

      assert html =~ "Bank"
      assert html =~ "auto loan"
      assert html =~ "$5,000"
      assert html =~ "$50"
      assert has_element?(page, ~s(button[phx-click="delete"][phx-value-id="#{unpaid.id}"]))
      refute has_element?(page, ~s(button[phx-click="delete"][phx-value-id="#{paid.id}"]))
    end

    test "search by lendee and sort", %{conn: conn} do
      for name <- ~w(Bob Alice Carol), do: loan_fixture(%{paid_to: name})
      {_view, page} = open_page(conn, @page)

      render_click(page, "sort", %{"field" => "paid_to"})
      assert lendees(page) == ~w(Alice Bob Carol)
      render_click(page, "sort", %{"field" => "paid_to"})
      assert lendees(page) == ~w(Carol Bob Alice)

      render_click(page, "search", %{"field" => "paid_to"})
      render_change(page, "search", %{"search" => %{"field" => "paid_to", "val" => "Ali"}})
      assert lendees(page) == ~w(Alice)
    end

    test "shows 50 loans and loads more", %{conn: conn} do
      for _ <- 1..52, do: loan_fixture()
      {_view, page} = open_page(conn, @page)

      assert loan_rows(page) == 50
      render_click(page, "load_more", %{})
      assert loan_rows(page) == 52
    end

    test "loans and repayments changed elsewhere show up live", %{conn: conn} do
      loan = loan_fixture(%{paid_to: "Before"})
      {_view, page} = open_page(conn, @page)

      {:ok, _} = Loans.create_or_update(loan, %{paid_to: "After"})
      assert render(page) =~ "After"

      # A repayment elsewhere refreshes the row too, but HomeLive reloads it with
      # LoanRepayment.Repo, which can't see this test's sandboxed HfgPortal.Repo data.

      other = loan_fixture(%{paid_to: "Newcomer"})
      assert render(page) =~ "Newcomer"
      Loans.delete(other)
      refute render(page) =~ "Newcomer"
    end
  end

  describe "loan modal" do
    test "bad amount shows an error; a good loan saves", %{conn: conn, user: user} do
      {_view, page} = open_page(conn, @page)
      render_click(page, "add_new", %{})

      html = page |> form("#loan form", %{"loan" => %{"paid_to" => "Uncle", "amount" => "lots"}}) |> render_submit()
      assert html =~ "is invalid"
      assert Loans.list(%{}) == []

      page
      |> form("#loan form", %{"loan" => %{"paid_to" => "Uncle", "for" => "Boat", "description" => "summer", "amount" => "1200"}})
      |> render_submit()

      refute has_element?(page, "#loan")
      assert [loan] = Loans.list(%{})
      assert %{paid_to: "Uncle", for: "Boat", description: "summer", created_by_id: id} = loan
      assert Decimal.equal?(loan.amount, 1200)
      assert id == user.id
      assert render(page) =~ "Uncle"
    end

    test "edit and delete", %{conn: conn} do
      loan = loan_fixture(%{paid_to: "Old"})
      {_view, page} = open_page(conn, @page)

      render_click(page, "edit", %{"id" => "#{loan.id}"})
      page |> form("#loan form", %{"loan" => %{"paid_to" => "New"}}) |> render_submit()
      assert Loans.get(loan.id).paid_to == "New"
      assert lendees(page) == ["New"]

      render_click(page, "delete", %{"id" => "#{loan.id}"})
      assert Loans.get(loan.id) == nil
      assert loan_rows(page) == 0
    end
  end

  describe "repayment modal" do
    setup %{conn: conn} do
      loan = loan_fixture(%{paid_to: "Sis", amount: Decimal.new(100)})
      {_view, page} = open_page(conn, @page)
      render_click(page, "repayment", %{"id" => "#{loan.id}"})
      %{loan: loan, page: page, modal: find_live_child(page, "modal_repayment_repayment")}
    end

    test "shows the loan in the header", %{modal: modal} do
      assert render(modal) =~ "$100 to Sis - Repayments"
    end

    test "repayments add up and the remaining balance goes down", %{loan: loan, modal: modal, user: user} do
      pay(modal, "40")
      pay(modal, "25")

      [second, first] = Repayments.list(%{loan_id: loan.id})
      assert Decimal.equal?(first.paid_amount_tot, 40)
      assert Decimal.equal?(first.remaining_balance, 60)
      assert Decimal.equal?(second.paid_amount, 25)
      assert Decimal.equal?(second.paid_amount_tot, 65)
      assert Decimal.equal?(second.remaining_balance, 35)
      assert second.created_by_id == user.id

      html = render(modal)
      assert html =~ "$65"
      assert html =~ "$35"
    end

    test "a bad amount shows an error and saves nothing", %{loan: loan, modal: modal} do
      html = modal |> form("form", %{"repayment" => %{"paid_amount" => "abc"}}) |> render_submit()
      assert html =~ "is invalid"
      assert Repayments.list(%{loan_id: loan.id}) == []
    end

    test "done closes it", %{page: page, modal: modal} do
      render_click(modal, "cancel", %{})
      assert find_live_child(page, "modal_repayment_repayment") == nil
    end

    test "survives another loan's repayment", %{modal: modal} do
      repayment_fixture(loan_fixture(), 1, 0)
      assert render(modal) =~ "Repayments"
    end
  end

  defp pay(modal, amount) do
    modal |> form("form", %{"repayment" => %{"paid_amount" => amount}}) |> render_submit()
    # let the PubSub "created" message (which updates the last total in the form) land
    :sys.get_state(modal.pid)
  end

  defp lendees(page) do
    page
    |> render()
    |> Floki.parse_fragment!()
    |> Floki.find(~s(tr[phx-click="repayment"] td:first-child))
    |> Enum.map(&String.trim(Floki.text(&1)))
  end
end
