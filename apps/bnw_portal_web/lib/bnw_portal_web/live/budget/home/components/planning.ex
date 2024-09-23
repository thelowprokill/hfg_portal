defmodule BnwPortalWeb.Budget.Home.Components.Planning do
  use BnwPortalWeb, :live_component

  alias BnwPortalWeb.Budget.Home.Components.Planning.{
    VariablePlanningLine,
    FixedPlanningLine,
    ExtraPlanningLine,
  }

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,               :map,     required: true
  attr :draft,           :map,     required: true
  attr :locked,          :boolean, required: true
  attr :selected,        :map,     required: true
  attr :variable_inputs, :list,    required: true
  def planning(assigns) do
    ~H"""
      <div class="w-[97%] pr-8 mr-8">
        <%
          department_accounts =
            @draft.company_budget.budget_accounts
            |> Enum.group_by(&(&1.department_account.department.id))
            |> Enum.map(fn {k, v} -> %{id: k, department: Enum.at(v, 0).department_account.department, value: v} end)
        %>
        <%= for department_account <- department_accounts do %>
          <.department
            f={@f}
            draft={@draft}
            locked={@locked}
            selected={@selected}
            department_account={department_account}
            variable_inputs={@variable_inputs}
          />
        <% end %>
      </div>
    """
  end

  attr :f,                  :map,     required: true
  attr :draft,              :map,     required: true
  attr :locked,             :boolean, required: true
  attr :selected,           :map,     required: true
  attr :department_account, :map,     required: true
  attr :variable_inputs,    :list,    required: true
  defp department(assigns) do
    ~H"""
      <div class="p-1">
        <div class="p-1 w-full flex">
          <.bnw_button phx-value-id={@department_account.department.id} phx_click="select_department">
            <%= "#{@department_account.department.name} (#{@department_account.department.department_number})" %>
          </.bnw_button>
          <div class="flex-grow"></div>
          <div class="px-2"><%= calculate_total(@f, @draft, @department_account.value) |> Number.Currency.number_to_currency %></div>
          <.bnw_icon bnw_icon={if @department_account.id in @selected.departments, do: "minus", else: "plus"} />
        </div>
        <hr />
        <div class="mx-8 my-4" hidden={!(@department_account.id in @selected.departments)}>
          <%= for %{department_account: da} <- @department_account.value do %>
            <.account
              f={@f}
              draft={@draft}
              locked={@locked}
              selected={@selected}
              department_account={da}
              variable_inputs={@variable_inputs}
            />
          <% end %>
        </div>
      </div>
    """
  end

  attr :f,                  :map,     required: true
  attr :draft,              :map,     required: true
  attr :locked,             :boolean, required: true
  attr :selected,           :map,     required: true
  attr :department_account, :map,     required: true
  attr :variable_inputs,    :list,    required: true
  defp account(assigns) do
    ~H"""
      <div class="p-1">
        <%
          expand = Enum.any?(
            @selected.accounts,
            &(&1 == @department_account.id)
          )
        %>
        <div class="p-1 w-full flex">
          <.bnw_button phx-value-department_account_id={@department_account.id} phx_click="select_account"><%= @department_account.account.name %></.bnw_button>
          <div class="flex-grow"></div>
          <div class="px-2"><%= calculate_total(@draft, @department_account.id) |> Number.Currency.number_to_currency %></div>
          <.bnw_icon bnw_icon={if expand, do: "minus", else: "plus"} />
        </div>
        <hr />
        <div class="mx-8 my-4" hidden={!expand}>
          <.planning_line 
              f={@f} 
              selected={@selected} 
              department_account={@department_account} 
              pl_type="v" 
              total={VariablePlanningLine.calculate_total(@draft, @department_account.id)}>
            <:title>Variable</:title>
            <VariablePlanningLine.variable_planning_line
              f={@f}
              expand={expand}
              draft={@draft}
              locked={@locked}
              department_account={@department_account}
              variable_inputs={@variable_inputs}
            />
          </.planning_line>
          <.planning_line 
              f={@f} 
              selected={@selected}
              department_account={@department_account} 
              pl_type="f" 
              total={FixedPlanningLine.calculate_total(@draft, @department_account.id)}>
            <:title>Fixed</:title>
            <FixedPlanningLine.fixed_planning_line
              f={@f}
              expand={expand}
              draft={@draft}
              locked={@locked}
              department_account={@department_account}
            />
          </.planning_line>
          <.planning_line 
              f={@f} 
              selected={@selected} 
              department_account={@department_account} 
              pl_type="e" 
              total={ExtraPlanningLine.calculate_total(@draft, @department_account.id)}>
            <:title>Extra</:title>
            <ExtraPlanningLine.extra_planning_line
              f={@f}
              expand={expand}
              draft={@draft}
              locked={@locked}
              department_account={@department_account}
            />
          </.planning_line>
        </div>
      </div>
    """
  end

  attr :f,                  :map,    required: true
  attr :selected,           :map,    required: true
  attr :department_account, :map,    required: true
  attr :pl_type,            :string, required: true
  attr :total,              :any,    required: true
  slot :title,                       required: true
  slot :inner_block,                 required: true
  defp planning_line(assigns) do
    ~H"""
      <div class="p-1">
        <%
          expand = Enum.any?(
            @selected.planning_lines,
            &(&1.department_account_id == @department_account.id && &1.planning_line_id == @pl_type)
          )
        %>
        <div class="p-1 w-full flex">
          <.bnw_button
            phx-value-department_account_id={@department_account.id}
            phx-value-planning_line_id={@pl_type}
            phx_click="select_planning_line">
            <%= render_slot(@title) %>
          </.bnw_button>
          <div class="flex-grow"></div>
          <div class="px-2"><%= @total |> Number.Currency.number_to_currency %></div>
          <.bnw_icon bnw_icon={if expand, do: "minus", else: "plus"} />
        </div>
        <hr />
        <div class="mx-8 my-4" hidden={!expand}>
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    """
  end

  def calculate_total(_f, draft, department_accounts) when is_list(department_accounts) do
    Enum.reduce(department_accounts, Decimal.new(0), fn x, acc -> calculate_total(draft, x.department_account_id) |> Decimal.add(acc) end)
  end
  def calculate_total(draft, department_account_id) do
    VariablePlanningLine.calculate_total(draft, department_account_id)
    |> Decimal.add(FixedPlanningLine.calculate_total(draft, department_account_id))
    |> Decimal.add(ExtraPlanningLine.calculate_total(draft, department_account_id))
  end
end
