defmodule BnwPortalWeb.ItBudget.Budgets.Modals.ChangeBudgetAccounts do
  use BnwPortalWeb, :live_view

  alias ItBudget.{
    Accounts,
    AccountSubs,
    Repo
  }

  @module  ItBudget.BudgetAccounts
  @key     "budget_account"
  @preload [account_sub: :account]

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.bnw_modal id="accounts_modal" width="w-2/3">
        <.bnw_modal_header><%= @modal.budget_year %> - Accounts</.bnw_modal_header>
        <.bnw_modal_body>
          <.form :let={f}
            for={@changeset}
            phx-change="validate"
            phx-submit="save">
            <.bnw_table height="60vh" id="accounts_table">
              <:header>
                <th class="p-2">Account</th>
                <th class="p-2">Sub</th>
                <th class="p-2">Active</th>
                <th class="p-2">Edit Months</th>
                <th class="p-2"></th>
                <th class="p-2"></th>
              </:header>

              <tr id="new_item"><%= if @new do %><.edit_form f={f} budget_id={@budget_id} user_id={@modal.user.id} accounts={@accounts} /><% end %></tr>

              <%= for item <- @items do %>
                <tr id={"item_#{item.id}"}>
                  <%= cond do %>
                    <% !@new && item.id == @changeset.data.id -> %>
                      <.edit_form f={f} budget_id={@budget_id} cancel={true} user_id={@modal.user.id} accounts={@accounts} />
                    <% true -> %>
                      <td><%= item.account_sub.account.name %></td>
                      <td><%= item.account_sub.name %></td>
                      <td><.toggle_active active={item.active} item_id={item.id} /></td>
                      <td><.bnw_button_icon   phx-value-id={item.id} bnw_icon="settings" phx_click="expand" /></td>
                      <td><.bnw_button_edit   phx-value-id={item.id} /></td>
                      <td><.bnw_button_delete phx-value-id={item.id} /></td>
                  <% end %>
                </tr>
                <%= if item.id == @expanded do %>
                  <tr></tr>
                  <tr hidden={!Map.get(@changeset.changes, :use_all_months, false)}>
                    <td></td>
                    <td><.bnw_input_naked f={f} field={:use_all_months} display_name="Use All Months" type="checkbox"/></td>
                    <td><.bnw_input_naked f={f} field={:all_months} display_name="All Months" type="number" step="0.01"/></td>
                    <td></td>
                    <td></td>
                  </tr>
                  <tr hidden={Map.get(@changeset.changes, :use_all_months, false)}>
                    <td></td>
                    <td><%= if !Map.get(@changeset.changes, :use_all_months, false) do %><.bnw_input_naked f={f} field={:use_all_months} display_name="Use All Months" type="checkbox"/><% end %></td>
                    <td><.bnw_input_naked f={f} field={:month_0}  display_name="October"   type="number" step="0.01"/></td>
                    <td><.bnw_input_naked f={f} field={:month_1}  display_name="November"  type="number" step="0.01"/></td>
                    <td><.bnw_input_naked f={f} field={:month_2}  display_name="December"  type="number" step="0.01"/></td>
                    <td><.bnw_input_naked f={f} field={:month_3}  display_name="January"   type="number" step="0.01"/></td>
                  </tr>
                  <tr hidden={Map.get(@changeset.changes, :use_all_months, false)}>
                    <td></td>
                    <td></td>
                    <td><.bnw_input_naked f={f} field={:month_4}  display_name="February"  type="number" step="0.01"/></td>
                    <td><.bnw_input_naked f={f} field={:month_5}  display_name="March"     type="number" step="0.01"/></td>
                    <td><.bnw_input_naked f={f} field={:month_6}  display_name="April"     type="number" step="0.01"/></td>
                    <td><.bnw_input_naked f={f} field={:month_7}  display_name="May"       type="number" step="0.01"/></td>
                  </tr>
                  <tr hidden={Map.get(@changeset.changes, :use_all_months, false)}>
                    <td></td>
                    <td></td>
                    <td><.bnw_input_naked f={f} field={:month_8}  display_name="June"      type="number" step="0.01"/></td>
                    <td><.bnw_input_naked f={f} field={:month_9}  display_name="July"      type="number" step="0.01"/></td>
                    <td><.bnw_input_naked f={f} field={:month_10} display_name="August"    type="number" step="0.01"/></td>
                    <td><.bnw_input_naked f={f} field={:month_11} display_name="September" type="number" step="0.01"/></td>
                  </tr>
                <% end %>
              <% end %>
            </.bnw_table>
          </.form>
        </.bnw_modal_body>
        <.bnw_modal_footer><.bnw_button_done /></.bnw_modal_footer>
      </.bnw_modal>
    </div>
    """
  end

  attr :f,         :any, required: true
  attr :budget_id, :integer
  attr :accounts,  :list
  attr :user_id,   :integer
  attr :cancel,    :boolean, default: false
  def edit_form(assigns) do
    #assigns = assigns |> assign(:account_subs, assigns.accounts |> Enum.find(Enum.at(assigns.accounts, 0), &(&1.id == Map.get(assigns.f.source.changes, :account_id))) |> Map.get(:account_subs))

    ~H"""
      <% 
        account_subs = 
          @accounts 
        |> Enum.find(Enum.at(@accounts, 0), fn x -> 
            cond do
              Map.get(@f.source.changes, :account_id) -> x.id == Map.get(@f.source.changes, :account_id)
              Map.get(@f.source.data,    :account_id) -> x.id == Map.get(@f.source.data,    :account_id)
              true -> false
            end
          end)
        |> Map.get(:account_subs) 
      %>

      <.bnw_input_hidden f={@f} field={:budget_id} value={@budget_id} />
      <.bnw_input_hidden f={@f} field={:user_id}   value={@user_id} />
      <td><.bnw_input_naked f={@f} field={:account_id}     display_name="Account"     type="select" list={@accounts |> Enum.map(&([key: &1.name, value: &1.id]))}/></td>
      <td><.bnw_input_naked f={@f} field={:account_sub_id} display_name="Account Sub" type="select" list={account_subs |> Enum.map(&([key: &1.name, value: &1.id]))}/></td>
      <td><.bnw_input_naked f={@f} field={:active}         display_name=""            type="checkbox"/></td>
      <td></td>
      <td><%= if @cancel do %><.bnw_button_cancel phx_click="cancel_edit" /><% end %></td>
      <td><.bnw_button_submit /></td>
    """
  end

  attr :active,  :boolean, default: false
  attr :item_id, :integer
  def toggle_active(assigns) when assigns.active, do: ~H"<.bnw_button_icon bnw_icon='check' phx-value-id={@item_id} phx_click='deactivate'/>"
  def toggle_active(assigns), do:                     ~H"<.bnw_button_icon bnw_icon='ban'   phx-value-id={@item_id} phx_click='activate'/>"

  defp save(socket) do
    %{changeset: changeset} = socket.assigns
    cond do
      changeset.valid? ->
        changeset.data |> @module.create_or_update(changeset.changes)
        |> case do
          {:ok, _} -> socket |> assign(:changeset, @module.new_changeset()) |> assign(:new, true) |> assign(:expanded, 0)
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
      page:       page,
      per_page:   per_page,
      items:      items,
      budget_id:  budget_id,
    } = socket.assigns

    socket |> assign(:items, items ++ @module.list(
      %{
        page:       page, 
        per_page:   per_page,
        budget_id:  budget_id,
        preload:    @preload,
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end

  defp fetch_accounts(socket) do
    socket |> assign(:accounts, Accounts.list(%{preload: [:account_subs]}))
  end

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
      Accounts.subscribe()
      AccountSubs.subscribe()
    end

    socket 
    |> assign(:modal,     modal)
    |> assign(:parent,    parent)
    |> assign(:budget_id, modal.budget_id)
    |> assign(:page,      0)
    |> assign(:per_page,  10)
    |> assign(:items,     [])
    |> assign(:accounts,  [])
    |> assign(:changeset, @module.new_changeset())
    |> assign(:expanded,  0)
    |> assign(:new,       true)
    |> fetch_items()
    |> fetch_accounts()
    |> res(:ok)
  end

  #budget_account
  @impl true
  def handle_info({[:budget_account, :created], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, [item |> Repo.preload(@preload) | items]) |> res()
  end
  @impl true
  def handle_info({[:budget_account, :updated], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.map(items, &(if &1.id == item.id, do: item |> Repo.preload(@preload), else: &1))) |> res()
  end
  @impl true
  def handle_info({[:budget_account, :deleted], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.reject(items, &(&1.id == item.id))) |> res()
  end

  #account
  @impl true
  def handle_info({[:account, :created], account}, socket) do
    %{accounts: accounts} = socket.assigns
    socket |> assign(:accounts, accounts ++ [%{account | account_subs: []}]) |> res()
  end
  @impl true
  def handle_info({[:account, :updated], account}, socket) do
    %{accounts: accounts} = socket.assigns
    socket |> assign(:accounts, Enum.map(accounts, &(if &1.id == account.id, do: %{account | account_subs: &1.account_subs}, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:account, :deleted], account}, socket) do
    %{accounts: accounts} = socket.assigns
    socket |> assign(:accounts, Enum.reject(accounts, &(&1.id == account.id))) |> res()
  end

  #account_sub
  @impl true
  def handle_info({[:account_sub, :created], account_sub}, socket) do
    %{accounts: accounts} = socket.assigns

    socket |> assign(:accounts, Enum.map(accounts, fn a -> (if a.id == account_sub.account_id, do: %{a | account_subs: a.account_subs ++ [account_sub]}, else: a) end)) |> res()
  end
  @impl true
  def handle_info({[:account_sub, :updated], account_sub}, socket) do
    %{accounts: accounts} = socket.assigns
    socket |> assign(:accounts, Enum.map(accounts, fn a -> (if a.id == account_sub.account_id, do: %{a | account_subs: Enum.map(a.account_subs, &(if &1.id == account_sub.id, do: account_sub, else: &1))}, else: a) end)) |> res()
  end
  @impl true
  def handle_info({[:account_sub, :deleted], account_sub}, socket) do
    %{accounts: accounts} = socket.assigns
    socket |> assign(:accounts, Enum.map(accounts, fn a -> (if a.id == account_sub.account_id, do: %{a | account_subs: Enum.reject(a.account_subs, &(&1.id == account_sub.id))}, else: a) end)) |> res()
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
    changeset = 
      id 
      |> String.to_integer() 
      |> @module.get() 
      |> fn x -> Map.put(x, :account_id, x.account_sub.account_id) end.()
      |> @module.change()
    socket |> assign(:changeset, changeset) |> assign(:new, false) |> res()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id |> String.to_integer() |> @module.delete()
    socket |> res()
  end

  @impl true
  def handle_event("expand", %{"id" => id}, socket) do
    %{expanded: expanded} = socket.assigns
    id = String.to_integer(id)

    cond do
      id == expanded -> socket |> assign(:expanded, 0) |> assign(:changeset, @module.new_changeset) |> assign(:new, true) |> res()
      true -> 
        socket 
        |> assign(:expanded, id) 
        |> assign(:changeset, id |> @module.get() |> @module.preload(%{preload: @preload}) |> fn x -> Map.put(x, :account_id, x.account_sub.account_id) end.() |> @module.change()) 
        |> assign(:new, false) |> res()
    end
  end

  @impl true
  def handle_event("cancel_edit", _, socket), do: socket |> assign(:changeset, @module.new_changeset) |> assign(:new, true) |> assign(:expanded, 0) |> res()

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


