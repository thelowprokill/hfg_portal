defmodule BnwPortalWeb.Budget.Home.Components.Assumptions.MiscIncome do
  use BnwPortalWeb, :live_component

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,               :map,     required: true
  attr :draft,           :map,     required: true
  attr :locked,          :boolean, required: true
  attr :variable_inputs, :list,    required: true
  def misc_income(assigns) do
    ~H"""
      <div class="my-4">
        <.bnw_table id={"misc_income_#{@draft.id}"} height="40vh" load_more={false}>
          <:header>
            <th class="p-2" style={"min-width: #{if @locked, do: "20px", else: "100px"};"}></th>
            <%= for month <- 1..12 do %>
              <th class="p-2" style={"min-width: #{if @locked, do: "20px", else: "100px"};"}> 
              <%= get_month_name(month, @draft.company_budget.starting_month) |> String.slice(0..2) %> 
              <%= @draft.year + cond do
                @draft.company_budget.starting_month + month <= 13 && @draft.company_budget.starting_month > 6  -> -1
                @draft.company_budget.starting_month + month > 13  && @draft.company_budget.starting_month <= 6 -> 1
                true -> 0
              end %>
              </th>
            <% end %>
          </:header>
          <%= for {variable_input, i} <- @variable_inputs |> Enum.filter(&(&1.misc)) |> Enum.with_index do %>
            <.item 
              f={@f} 
              key="misc_incomes"
              draft={@draft} 
              locked={@locked}
              variable_input={variable_input} 
              data={Enum.find(@draft.misc_incomes, %{new: true, id: -1 * i}, &(&1.variable_input_id == variable_input.id))} 
            />
          <% end %>
        </.bnw_table>
      </div>
    """
  end

  attr :f,               :map,     required: true
  attr :key,             :string,  required: true
  attr :variable_input,  :map,     required: true
  attr :draft,           :map,     required: true
  attr :locked,          :boolean, required: true
  attr :data,            :map,     required: true
  defp item(assigns) when assigns.locked == false do
    ~H"""
      <tr>
        <.bnw_input_hidden f={@f} field={:id}    name={"draft[#{@key}_#{@data.id}][id]"}    value={@data.id} />
        <.bnw_input_hidden f={@f} field={:index} name={"draft[#{@key}_#{@data.id}][index]"} value={@data.id} />
        <.bnw_input_hidden f={@f} field={:variable_input_id}   name={"draft[#{@key}_#{@data.id}][variable_input_id]"}   value={@variable_input.id} />
        <.bnw_input_hidden f={@f} field={:variable_input_name} name={"draft[#{@key}_#{@data.id}][variable_input_name]"} value={@variable_input.name} />
        <td class="p-2"><%= @variable_input.name %> </td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_1}  /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_2}  /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_3}  /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_4}  /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_5}  /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_6}  /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_7}  /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_8}  /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_9}  /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_10} /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_11} /></td>
        <td class="p-2"><.make_input f={@f} data={@data} key={@key} field={:month_12} /></td>
      </tr>
    """
  end

  defp item(assigns) do
    ~H"""
      <% curr = @draft.misc_incomes  |> Enum.find(%{}, &(&1.variable_input_id == @variable_input.id)) %>
      <tr>
        <td class="p-2"><%= @variable_input.name %> </td>
        <td class="p-2"><%= Map.get(curr, :month_1,  0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_2,  0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_3,  0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_4,  0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_5,  0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_6,  0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_7,  0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_8,  0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_9,  0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_10, 0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_11, 0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_12, 0) %></td>
      </tr>
    """
  end

  attr :f,     :map,    required: true
  attr :key,   :string, required: true
  attr :field, :any,    required: true
  attr :data,  :map,    required: true
  defp make_input(assigns) do
    ~H""" 
      <.bnw_input_naked 
        f={@f} 
        field={@field} 
        type={"number"} 
        name={"draft[#{@key}_#{@data.id}][#{@field |> Atom.to_string()}]"} 
        value={Map.get(@data, @field)} 
        step={if @key == "misc_income", do: "0.01", else: "1"} 
        debounce="blur"
      />
    """
  end
end

