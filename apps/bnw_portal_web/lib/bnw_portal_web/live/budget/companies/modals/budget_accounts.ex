defmodule BnwPortalWeb.Budget.Companies.Modals.ChangeBudgetAccounts do
  use BnwPortalWeb, :live_view

  alias Budget.{
    Admins,
    UserRoles,
    Roles,
    CompanyPermissions,
    CompanyDepartments,
    CompanyDepartmentAccounts,
    Repo,
  }

  @module  Budget.CompanyBudgetAccounts
  @key     "budget_accounts"
  @section "budgets"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="budget_accounts_modal">
          <.bnw_modal_header><%= @modal.opts.company_name %> - <%= @modal.opts.budget_name %> - Budget Depatments</.bnw_modal_header>
          <.bnw_modal_body>
            <.bnw_table height="60vh" id="budget_accounts_table">
              <:header>
                <th class="p-2 w-1/3" colspan="2">Number</th>
                <th class="p-2">Name</th>
                <th class="p-2">Active</th>
              </:header>


              <%= for item <- @items do %>
                <%= if length(item.department_accounts) > 0 do %>
                  <tr id={"item_#{item.id}"} class="cursor-pointer" phx-click="expand_department" phx-value-id={item.id}>
                    <td colspan="2"><%= item.department_number %></td>
                    <td><%= item.name %></td>
                    <td><.bnw_button_toggle_active edit={@edit} active={Enum.any?(@budget_accounts, fn x -> Enum.any?(item.department_accounts, &(x.department_account.id == &1.id)) end)} phx-value-id={item.id} phx_click_activate="activate_all" phx_click_deactivate="deactivate_all" /></td>
                  </tr>
                  <%= if @expanded_department == item.id do %>
                    <%= for account <- item.department_accounts do %>
                      <tr id={"account_#{account.id}"}>
                        <td class="w-1/4"></td>
                        <td><%= account.account.account_number %></td>
                        <td><%= account.account.name %></td>
                        <td><.bnw_button_toggle_active edit={@edit} active={Enum.any?(@budget_accounts, &(&1.department_account.id == account.id))} phx-value-id={account.id} /></td>
                      </tr>
                    <% end %>
                  <% end %>
                <% end %>
              <% end %>
            </.bnw_table>
          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_done id="a_different_done"/></.bnw_modal_footer>
        </.bnw_modal>
      <% end %>
    </div>
    """
  end

  defp fetch_user_permissions(socket) do
    %{
      modal:      %{user: user},
      company_id: company_id
    } = socket.assigns
    cond do 
      (user.dev_admin && user.admin_mode) || Admins.is_admin(user.id) -> socket |> assign(:edit, true) |> assign(:view, true)
      true ->
        %{company_permissions: company_permissions} = UserRoles.fetch_user_permissions(user.id)

        edit = Enum.any?(company_permissions, &(&1.company_id == company_id && &1.section == @section && &1.permission in ["admin", "edit"]))
        view = Enum.any?(company_permissions, &(&1.company_id == company_id && &1.section == @section))
        socket |> assign(:edit, edit) |> assign(:view, view)
    end
  end

  defp save(socket) do
    %{changeset: changeset} = socket.assigns
    cond do
      changeset.valid? ->
        changeset.data |> @module.create_or_update(changeset.changes)
        |> case do
          {:ok, _} -> socket |> assign(:changeset, @module.new_changeset()) |> assign(:new, true)
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

  defp fetch_budget_accounts(socket) do
    %{
      budget_accounts: budget_accounts,
      budget_id:       budget_id,
    } = socket.assigns

    socket |> assign(:budget_accounts, budget_accounts ++ @module.list(
      %{
        budget_id: budget_id,
        active:    true,
        preload:   [:department_account]
      }
    ))
  end

  defp fetch_items(socket) do
    %{
      page:       page,
      per_page:   per_page,
      items:      items,
      company_id: company_id,
    } = socket.assigns

    socket |> assign(:items, items ++ CompanyDepartments.list(
      %{
        page:       page,
        per_page:   per_page,
        company_id: company_id,
        active:     true,
        preload:    [department_accounts: :account],
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
      Admins.subscribe()
      CompanyDepartments.subscribe()
      CompanyDepartmentAccounts.subscribe()
      UserRoles.subscribe()
      Roles.subscribe()
      CompanyPermissions.subscribe()
    end

    socket
    |> assign(:modal,               modal)
    |> assign(:parent,              parent)
    |> assign(:budget_id,           modal.opts.budget_id)
    |> assign(:company_id,          modal.opts.company_id)
    |> assign(:page,                0)
    |> assign(:per_page,            30)
    |> assign(:items,               [])
    |> assign(:budget_accounts,     [])
    |> assign(:accounts,            [])
    |> assign(:new,                 true)
    |> assign(:edit,                false)
    |> assign(:view,                false)
    |> assign(:expanded_department, 0)
    |> fetch_items()
    |> fetch_budget_accounts()
    |> fetch_user_permissions()
    |> res(:ok)
  end

  #departments
  @impl true
  def handle_info({[:department, :created], item}, socket) do
    %{
      company_id: company_id,
      items:      items,
    } = socket.assigns
    cond do
      item.company_id == company_id -> socket |> assign(:items, [(item |> Map.put(:department_accounts, [])) | items]) |> res()
      true -> socket |> res()
    end
  end
  @impl true
  def handle_info({[:department, :updated], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.map(items, fn x -> if x.id == item.id, do: item |> Map.put(:department_accounts, x.department_accounts), else: x end)) |> res()
  end
  @impl true
  def handle_info({[:department, :deleted], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.reject(items, &(&1.id == item.id))) |> res()
  end

  #department_accounts
  @impl true
  def handle_info({[:department_account, :created], item}, socket) do
    %{items: items} = socket.assigns
    cond do
      Enum.any?(items, &(&1.id == item.department_id)) ->
        socket
        |> assign(:items, Enum.map(
          items,
          &(if &1.id == item.department_id, do: %{&1 | department_accounts: &1.department_accounts ++ [item]}, else: &1)
        )) |> res()
      true -> socket |> res()
    end
  end
  @impl true
  def handle_info({[:department_account, :deleted], item}, socket) do
    %{items: items} = socket.assigns
    socket |> assign(:items, Enum.map(items,
      fn x -> if x.id == item.department_id, do: %{x | department_accounts: Enum.reject(x.department_accounts, &(&1.id == item.id))}, else: x end))
      |> res()
  end

  #budget_accounts
  @impl true
  def handle_info({[:budget_account, :created], item}, socket) do
    %{
      budget_accounts: budget_accounts,
      budget_id:       budget_id,
    } = socket.assigns
    cond do
      item.company_budget_id == budget_id -> socket |> assign(:budget_accounts, [item |> Repo.preload(:department_account) | budget_accounts]) |> res()
      true -> socket |> res()
    end
  end
  @impl true
  def handle_info({[:budget_account, :deleted], item}, socket) do
    %{budget_accounts: budget_accounts} = socket.assigns
    socket |> assign(:budget_accounts, Enum.reject(budget_accounts, &(&1.id == item.id))) |> res()
  end

  @impl true
  def handle_info({[:budget, _, _], _}, socket) do
    socket |> fetch_user_permissions() |> res()
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
  def handle_event("cancel_edit", _, socket), do: socket |> assign(:changeset, @module.new_changeset) |> assign(:new, true) |> res()

  @impl true
  def handle_event("cancel", _, socket) do
    cancel(socket) |> res()
  end

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_items()
    |> res()
  end

  @impl true
  def handle_event("expand_department", %{"id" => id}, socket) do
    %{expanded_department: expanded_department} = socket.assigns
    cond do
      expanded_department == id |> String.to_integer() -> socket |> assign(:expanded_department, 0)
      true -> socket |> assign(:expanded_department, id |> String.to_integer())
    end |> res()
  end

  @impl true
  def handle_event("deactivate", %{"id" => id}, socket) do
    %{budget_accounts: budget_accounts} = socket.assigns
    id = id |> String.to_integer()
    budget_accounts
    |> Enum.find(&(&1.department_account_id == id))
    |> Map.get(:id)
    |> @module.delete()
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"id" => id}, socket) do
    %{budget_id: budget_id} = socket.assigns

    @module.new()
    |> @module.create_or_update(
    %{
      company_budget_id:     budget_id,
      department_account_id: id,
    })
    socket |> res()
  end

  @impl true
  def handle_event("deactivate_all", %{"id" => id}, socket) do
    %{
      budget_accounts: budget_accounts,
      items:           items,
    } = socket.assigns
    del_items =
      items
      |> Enum.find(&(&1.id == id |> String.to_integer()))
      |> Map.get(:department_accounts)
      |> Enum.map(&(&1.id))
    budget_accounts
    |> Enum.filter(&(&1.department_account_id in del_items))
    |> Enum.map(&(&1.id))
    |> Enum.each(&@module.delete/1)
    socket |> res()
  end

  @impl true
  def handle_event("activate_all", %{"id" => id}, socket) do
    %{
      budget_id: budget_id,
      items:     items,
    } = socket.assigns

    items
    |> Enum.find(&(&1.id == id |> String.to_integer()))
    |> Map.get(:department_accounts)
    |> Enum.map(&(&1.id))
    |> Enum.map(&(@module.new() |> @module.create_or_update(%{company_budget_id: budget_id, department_account_id: &1})))
    socket |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end



