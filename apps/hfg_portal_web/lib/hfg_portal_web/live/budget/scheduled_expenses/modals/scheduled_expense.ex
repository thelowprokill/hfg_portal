defmodule HfgPortalWeb.Budget.ScheduledExpenses.Modals.ChangeScheduledExpense do
  use HfgPortalWeb, :live_component

  @module Budget.ScheduledExpenses
  @key    "scheduled_expense"

  @frequencies [
    [key: "Monthly", value: "monthly"],
    [key: "Weekly",  value: "weekly"],
    [key: "Yearly",  value: "yearly"],
  ]

  @days_of_week [
    [key: "Monday",    value: 0],
    [key: "Tuesday",   value: 1],
    [key: "Wednesday", value: 2],
    [key: "Thursday",  value: 3],
    [key: "Friday",    value: 4],
    [key: "Saturday",  value: 5],
    [key: "Sunday",    value: 6],
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="scheduled_expense">
        <.bnw_modal_header><.bnw_modal_new_or_edit changeset={@modal.changeset}>Scheduled Expense</.bnw_modal_new_or_edit></.bnw_modal_header>
        <.form :let={f}
          for={@modal.changeset}
          phx-target={@myself}
          phx-change="validate"
          phx-submit="save">
          <.bnw_modal_body>

            <% bucket_list = Enum.map(@modal.opts.buckets, &[key: &1.name, value: &1.id]) %>
            <.bnw_input f={f} type="select" field={:bucket_id}   display_name="Bucket"      list={bucket_list} />
            <.bnw_input f={f} field={:description}               display_name="Description" />
            <.bnw_input f={f} type="money"  field={:amount}      display_name="Amount" />
            <.bnw_input f={f} type="select" field={:frequency}   display_name="Frequency"   list={@frequencies} />

            <% frequency = Phoenix.HTML.Form.input_value(f, :frequency) %>

            <%= if frequency == "weekly" do %>
              <.bnw_input f={f} type="select"  field={:day_of_week}   display_name="Day of Week" list={@days_of_week} />
            <% end %>

            <%= if frequency in ["monthly", "yearly"] do %>
              <.bnw_input f={f} type="number" field={:day_of_month} display_name="Day of Month (1–28)" min={1} max={28} step={1} />
            <% end %>

            <%= if frequency == "yearly" do %>
              <.bnw_input f={f} type="month" field={:month_of_year} display_name="Month" />
            <% end %>

            <.bnw_input f={f} type="date"    field={:next_due_date} display_name="Next Due Date" />
            <.bnw_input_naked f={f} field={:active} type="checkbox" display_name="Active" />

          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_cancel /><.bnw_button_submit /></.bnw_modal_footer>
        </.form>
      </.bnw_modal>
    </div>
    """
  end

  defp save(socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns

    if changeset.valid? do
      changeset.data
      |> @module.create_or_update(changeset.changes)
      |> case do
        {:ok, _}     -> cancel(socket)
        {:error, cs} -> socket |> assign(:modal, %{modal | changeset: cs})
      end
    else
      socket
    end
  end

  defp cancel(socket) do
    send(self(), :cancel)
    socket
  end

  @impl true
  def mount(socket) do
    socket
    |> assign(:frequencies,  @frequencies)
    |> assign(:days_of_week, @days_of_week)
    |> res(:ok)
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns
    params = Map.get(params, @key, %{})
    changeset = changeset.data |> @module.change(params) |> Map.put(:action, :insert)
    socket |> assign(:modal, %{modal | changeset: changeset}) |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{modal: %{changeset: changeset} = modal} = socket.assigns
    params = Map.get(params, @key, %{})
    changeset = changeset.data |> @module.change(params) |> Map.put(:action, :insert)
    socket |> assign(:modal, %{modal | changeset: changeset}) |> save() |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
