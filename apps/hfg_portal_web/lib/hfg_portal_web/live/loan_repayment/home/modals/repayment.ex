defmodule HfgPortalWeb.LoanRepayment.Home.Modals.ChangeRepayment do
  use HfgPortalWeb, :live_view

  @module  LoanRepayment.Repayments
  @key     "repayment"
  @preload []

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="repayments_modal" width="w-full">
          <.bnw_modal_header><%= @modal.opts.loan.amount |> Number.Currency.number_to_currency(precision: 0) %> to <%= @modal.opts.loan.paid_to %> - Repayments</.bnw_modal_header>
          <.bnw_modal_body>
            <.form :let={f}
              for={@changeset}
              phx-change="validate"
              phx-submit="save">
              <.bnw_table height="60vh" id="timesheets_table">
                <:header>
                  <th class="p-2">Paid Amount</th>
                  <th class="p-2">Remainging Balance</th>
                  <th class="p-2">Total Paid</th>
                  <th class="p-2">Date Paid</th>
                </:header>

                <tr id="new_item">
                  <%= if @new && @edit do %>
                    <.edit_form 
                      f={f} 
                      loan_id={@loan_id} 
                      user_id={@user.id} 
                      loan_amount={@modal.opts.loan.amount}
                      last_item={@items |> Enum.max_by(&(&1.paid_amount_tot), fn -> %{paid_amount_tot: 0, remaining_balance: @modal.opts.loan.amount} end)}
                    />
                  <% end %>
                </tr>

                <%= for item <- @items do %>
                  <tr id={"item_#{item.id}"}>
                    <%= cond do %>
                      <% !@new && @edit && item.id == @changeset.data.id -> %>
                        <.edit_form 
                          f={f} 
                          loan_id={@loan_id} 
                          user_id={@user.id} 
                          cancel={true} 
                          loan_amount={@modal.opts.loan.amount}
                          last_item={@items |> Enum.max_by(&(&1.paid_amount_tot), fn -> %{paid_amount_tot: 0, remaining_balance: @moadl.opts.loan.amount} end)}
                        />
                      <% true -> %>
                        <td class="px-2 text-right"><%= item.paid_amount |> Number.Currency.number_to_currency(precision: 0) %></td>
                        <td class="px-2 text-right"><%= Decimal.sub(@modal.opts.loan.amount, item.paid_amount_tot) |> Number.Currency.number_to_currency(precision: 0) %></td>
                        <td class="px-2 text-right"><%= item.paid_amount_tot |> Number.Currency.number_to_currency(precision: 0) %></td>
                        <td class="px-2"><%= item.updated_at |> Calendar.strftime("%Y-%m-%d %H:%M") %></td>
                    <% end %>
                  </tr>
                <% end %>
              </.bnw_table>
            </.form>
          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_done /></.bnw_modal_footer>
        </.bnw_modal>
      <% end %>
    </div>
    """
  end

  attr :f,                :any, required: true
  attr :loan_id,          :integer
  attr :user_id,          :integer
  attr :cancel,           :boolean, default: false
  attr :last_item,        :map
  attr :loan_amount,      :any
  def edit_form(assigns) do
    ~H"""
      <%= if !@cancel do %>
        <.bnw_input_hidden f={@f} field={:created_by_id}  value={@user_id} />
      <% end %>
      <.bnw_input_hidden f={@f} field={:loan_id}          value={@loan_id} />
      <.bnw_input_hidden f={@f} field={:updated_by_id}    value={@user_id} />
      <.bnw_input_hidden f={@f} field={:last_paid_amount} value={@last_item.paid_amount_tot} />
      <.bnw_input_hidden f={@f} field={:loan_amount}      value={@loan_amount} />

      <td class="px-2"><.bnw_input_naked f={@f} type="number"   field={:paid_amount}  display_name="Paid Amount"/></td>
      <td class="px-2"></td>
      <td class="px-2"><%= if @cancel do %><.bnw_button_cancel phx_click="cancel_edit" /><% end %></td>
      <td class="px-2"><.bnw_button_submit /></td>
    """
  end

  attr :active,  :boolean, default: false
  attr :item_id, :integer
  def toggle_active(assigns) when assigns.active, do: ~H"""
    <.bnw_button_icon
      class='text-success-main hover:text-success-hover' 
      bnw_icon='check'
      phx-value-id={@item_id}
      phx_click='deactivate'
    />
    """
  def toggle_active(assigns), do: ~H"""
    <.bnw_button_icon
      class='text-danger-main hover:text-danger-hover' 
      bnw_icon='ban'
      phx-value-id={@item_id}
      phx_click='activate'
    />
    """

  defp save(socket) do
    %{changeset: changeset} = socket.assigns
    cond do
      changeset.valid? ->
        changeset.data |> @module.create_or_update(changeset.changes)
        |> case do
          {:ok, _} -> socket |> assign(:changeset, @module.new_changeset(%{entry_date: Date.utc_today()})) |> assign(:new, true)
          {:error, changeset} -> socket |> assign(:changeset, changeset)
        end
      true -> socket
    end
  end

  defp cancel(socket) do
    %{parent: parent} = socket.assigns
    send(parent, :cancel)
    socket
  end

  defp fetch_items(socket) do
    %{
      page:     page,
      per_page: per_page,
      items:    items,
      loan_id:  loan_id,
    } = socket.assigns

    socket |> assign(:items, items ++ @module.list(
      %{
        page:     page,
        per_page: per_page,
        loan_id:  loan_id,
        mileage:  false,
        preload:  @preload,
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
      #Admins.subscribe()
      #UserRoles.subscribe()
      #Roles.subscribe()
      #CompanyPermissions.subscribe()
    end

    socket
    |> assign(:modal,            modal)
    |> assign(:parent,           parent)
    |> assign(:loan_id,          modal.opts.loan.id)
    |> assign(:user,             modal.user)
    |> assign(:page,             0)
    |> assign(:per_page,         30)
    |> assign(:items,            [])
    |> assign(:changeset,        @module.new_changeset())
    |> assign(:new,              true)
    |> assign(:edit,             true)
    |> assign(:view,             true)
    |> fetch_items()
    |> res(:ok)
  end

  @impl true
  def handle_info({[_, :created], item}, socket) do
    cond do
      (item.loan_id == socket.assigns.loan_id && !is_nil(item.loan_id)) || (item.fixed_loan_id == socket.assigns.fixed_loan_id && !is_nil(item.fixed_loan_id)) ->
        %{items: items} = socket.assigns
        socket |> assign(:items, [item |> @module.preload_associations(%{preload: @preload}) | items] |> Enum.uniq_by(&(&1.id)))
      true -> socket
    end |> res()
  end
  @impl true
  def handle_info({[_, :updated], item}, socket) do
    cond do
      (item.loan_id == socket.assigns.loan_id && !is_nil(item.loan_id)) || (item.fixed_loan_id == socket.assigns.fixed_loan_id && !is_nil(item.fixed_loan_id)) ->
        %{items: items} = socket.assigns
        socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item |> @module.preload_associations(%{preload: @preload}), else: &1))) |> res()
      true -> socket
    end |> res()
  end
  @impl true
  def handle_info({[_, :deleted], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.reject(items, &(&1.id == item.id))) |> res()
  end

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{changeset: changeset} = socket.assigns
    changeset =
      changeset.data
      |> @module.change(params |> Map.get(@key, %{}))
      |> Map.put(:action, :insert)

    socket
    |> assign(:changeset, changeset)
    |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{changeset: changeset} = socket.assigns

    changeset =
      changeset.data
      |> @module.change(params |> Map.get(@key, %{}))
      |> Map.put(:action, :insert)

    socket
    |> assign(:changeset, changeset)
    |> save()
    |> res()
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    changeset = id |> String.to_integer() |> @module.get() |> @module.change()
    socket |> assign(:changeset, changeset) |> assign(:new, false) |> res()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id |> String.to_integer() |> @module.delete()
    socket |> res()
  end

  @impl true
  def handle_event("cancel_edit", _, socket), do: socket |> assign(:changeset, @module.new_changeset(%{entry_date: Date.utc_today()})) |> assign(:new, true) |> res()

  @impl true
  def handle_event("cancel", _, socket), do: cancel(socket) |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_items()
    |> res()
  end

  @impl true
  def handle_event("deactivate", %{"id" => id}, socket) do
    id |> String.to_integer() |> @module.deactivate()
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    id |> String.to_integer() |> @module.activate()
    socket |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
