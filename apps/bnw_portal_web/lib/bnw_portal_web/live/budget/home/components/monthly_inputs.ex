defmodule BnwPortalWeb.Budget.Home.Components.MonthlyInputs do
  use BnwPortalWeb, :live_component

  #alias BnwPortalWeb.Budget.Home.Components.{
  #  Assumptions,
  #  Planning,
  #  Reports,
  #}

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,               :map,     required: true
  attr :draft,           :map,     required: true
  attr :locked,          :boolean, required: true
  attr :variable_inputs, :list,    required: true
  def monthly_inputs(assigns) do
    ~H"""
      <div class="my-4">
        <.bnw_table id={"monthly_inputs_#{@draft.id}"} height="60vh" load_more={false}>
          <:header>
            <th class="p-2"></th>
            <%= for month <- 1..12 do %>
              <th class="p-2 min-w-[100px]"> 
                <%= get_month_name(month, @draft.company_budget.starting_month) |> String.slice(0..2) %> 
                <%= @draft.year + cond do
                  @draft.company_budget.starting_month + month <= 13 && @draft.company_budget.starting_month > 6  -> -1
                  @draft.company_budget.starting_month + month > 13  && @draft.company_budget.starting_month <= 6 -> 1
                  true -> 0
                end %>
              </th>
            <% end %>
          </:header>
          <%= for vi <- @variable_inputs do %>
            <.item 
              f={@f} 
              draft={@draft} 
              locked={@locked}
              variable_input={vi}
            />
          <% end %>
        </.bnw_table>
      </div>
    """
  end

  attr :f,              :map,     required: true
  attr :draft,          :map,     required: true
  attr :locked,         :boolean, required: true
  attr :variable_input, :map,     required: true
  def item(assigns) when assigns.locked == false do
    ~H"""
      <tr>
        <%
          data = Enum.find(@draft.monthly_inputs, %{}, &(&1.variable_input_id == @variable_input.id))
        %>
        <.bnw_input_hidden f={@f} field={:variable_input_id} name={"draft[monthly_inputs_#{@variable_input.id}][variable_input_id]"} value={@variable_input.id} />
        <td class="p-2"><%= @variable_input.name %></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_1}  /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_2}  /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_3}  /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_4}  /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_5}  /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_6}  /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_7}  /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_8}  /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_9}  /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_10} /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_11} /></td>
        <td class="p-2"><.make_input f={@f} data={data} variable_input={@variable_input} field={:month_12} /></td>
      </tr>
    """
  end
  def item(assigns) do
    ~H"""
      <tr>
        <%
          data = Enum.find(@draft.monthly_inputs, %{}, &(&1.variable_input_id == @variable_input.id))
        %>
        <.bnw_input_hidden f={@f} field={:variable_input_id} name={"draft[monthly_inputs_#{@variable_input.id}][variable_input_id]"} value={@variable_input.id} />
        <td class="p-2"><%= @variable_input.name %></td>
        <td class="p-2"><%= Map.get(data, :month_1 ) %></td>
        <td class="p-2"><%= Map.get(data, :month_2 ) %></td>
        <td class="p-2"><%= Map.get(data, :month_3 ) %></td>
        <td class="p-2"><%= Map.get(data, :month_4 ) %></td>
        <td class="p-2"><%= Map.get(data, :month_5 ) %></td>
        <td class="p-2"><%= Map.get(data, :month_6 ) %></td>
        <td class="p-2"><%= Map.get(data, :month_7 ) %></td>
        <td class="p-2"><%= Map.get(data, :month_8 ) %></td>
        <td class="p-2"><%= Map.get(data, :month_9 ) %></td>
        <td class="p-2"><%= Map.get(data, :month_10) %></td>
        <td class="p-2"><%= Map.get(data, :month_11) %></td>
        <td class="p-2"><%= Map.get(data, :month_12) %></td>
      </tr>
    """
  end

  attr :f,              :map,    required: true
  attr :variable_input, :map,    required: true
  attr :data,           :map,    required: true
  attr :field,          :any,    required: true
  attr :step,           :string, default: "0.01"
  def make_input(assigns) do
    ~H"""
      <.bnw_input_naked 
        f={@f} 
        field={@field} 
        type="number" 
        name={"draft[monthly_inputs_#{@variable_input.id}][#{@field |> Atom.to_string()}]"} 
        value={Map.get(@data, @field)} 
        step={@step} 
        debounce="blur" 
      />
    """
  end 
end




