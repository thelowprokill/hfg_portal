defmodule BnwPortalWeb.Budget.Home.Components.Assumptions.ConsumptionAssumptions do
  use BnwPortalWeb, :live_component

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,            :map,     required: true
  attr :draft,        :map,     required: true
  attr :locked,       :boolean, required: true
  attr :animal_sexes, :list,    required: true
  attr :animal_types, :list,    required: true
  def consumption(assigns) do
    ~H"""
      <div class="my-4">
        <.bnw_table id={"consumption_assumptions_#{@draft.id}"} height="40vh" load_more={false}>
          <:header>
            <th class="p-2" style={"min-width: #{if @locked, do: "20px", else: "100px"};"}></th>
            <th class="p-2" style={"min-width: #{if @locked, do: "20px", else: "100px"};"}>In</th>
            <th class="p-2" style={"min-width: #{if @locked, do: "20px", else: "100px"};"}>Out</th>
            <th class="p-2" style={"min-width: #{if @locked, do: "20px", else: "100px"};"}>Pop %</th>
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
            <th class="p-2" style={"min-width: #{if @draft.locked, do: "20px", else: "100px"};"}>DMI Total</th>
          </:header>
          <%= for {animal_sex, i} <- @animal_sexes |> Enum.with_index do %>
            <%= for {animal_type, j} <- @animal_types |> Enum.with_index do %>
              <.item 
                f={@f} 
                draft={@draft} 
                locked={@locked}
                type={animal_type} 
                sex={animal_sex} 
                assumption={Enum.find(@draft.consumption_assumptions, %{new: true, id: -1 * (i * length(@animal_types) + j + 1)}, &(&1.animal_sex_id == animal_sex.id and &1.animal_type_id == animal_type.id))} 
              />
            <% end %>
          <% end %>
        </.bnw_table>
      </div>
    """
  end

  attr :f,          :map,     required: true
  attr :sex,        :map,     required: true
  attr :type,       :map,     required: true
  attr :draft,      :map,     required: true
  attr :locked,     :boolean, required: true
  attr :assumption, :map,     required: true
  defp item(assigns) when assigns.locked == false do
    ~H"""
      <tr>
        <.bnw_input_hidden f={@f} field={:id}             name={"draft[consumption_assumptions_#{@assumption.id}][id]"}             value={@assumption.id} />
        <.bnw_input_hidden f={@f} field={:index}          name={"draft[consumption_assumptions_#{@assumption.id}][index]"}          value={@assumption.id} />
        <.bnw_input_hidden f={@f} field={:animal_sex_id}  name={"draft[consumption_assumptions_#{@assumption.id}][animal_sex_id]"}  value={@sex.id} />
        <.bnw_input_hidden f={@f} field={:animal_type_id} name={"draft[consumption_assumptions_#{@assumption.id}][animal_type_id]"} value={@type.id} />
        <td class="p-2"><%= "#{@type.name} #{@sex.name}" %></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:in_weight}      step="1"/></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:out_weight}     step="1"/></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:population_pct} step="1"/></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_1}        /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_2}        /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_3}        /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_4}        /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_5}        /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_6}        /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_7}        /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_8}        /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_9}        /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_10}       /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_11}       /></td>
        <td class="p-2"><.make_input f={@f} assumption={@assumption} field={:month_12}       /></td>
        <td class="p-2"><%= Map.get(@assumption, :total) %></td>
      </tr>
    """
  end

  defp item(assigns) do
    ~H"""
      <% curr = @draft.consumption_assumptions |> Enum.find(%{}, &(&1.animal_sex_id == @sex.id && &1.animal_type_id == @type.id)) %>
      <tr>
        <td class="p-2"><%= "#{@type.name} #{@sex.name}" %></td>
        <td class="p-2"><%= Map.get(curr, :in_weight,      0) %></td>
        <td class="p-2"><%= Map.get(curr, :out_weight,     0) %></td>
        <td class="p-2"><%= Map.get(curr, :population_pct, 0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_1,        0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_2,        0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_3,        0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_4,        0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_5,        0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_6,        0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_7,        0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_8,        0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_9,        0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_10,       0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_11,       0) %></td>
        <td class="p-2"><%= Map.get(curr, :month_12,       0) %></td>
        <td class="p-2">
          <%=
            Decimal.new("0")
            |> Decimal.add(Map.get(curr, :month_1,  Decimal.new("0"))) 
            |> Decimal.add(Map.get(curr, :month_2,  Decimal.new("0"))) 
            |> Decimal.add(Map.get(curr, :month_3,  Decimal.new("0"))) 
            |> Decimal.add(Map.get(curr, :month_4,  Decimal.new("0"))) 
            |> Decimal.add(Map.get(curr, :month_5,  Decimal.new("0"))) 
            |> Decimal.add(Map.get(curr, :month_6,  Decimal.new("0")))
            |> Decimal.add(Map.get(curr, :month_7,  Decimal.new("0")))
            |> Decimal.add(Map.get(curr, :month_8,  Decimal.new("0")))
            |> Decimal.add(Map.get(curr, :month_9,  Decimal.new("0")))
            |> Decimal.add(Map.get(curr, :month_10, Decimal.new("0")))
            |> Decimal.add(Map.get(curr, :month_11, Decimal.new("0")))
            |> Decimal.add(Map.get(curr, :month_12, Decimal.new("0")))
          %>
        </td>
      </tr>
    """
  end

  attr :f,          :map, required: true
  attr :field,      :any, required: true
  attr :assumption, :map, required: true
  attr :step,       :string, default: "0.01"
  defp make_input(assigns) do
    ~H""" 
      <.bnw_input_naked 
        f={@f} 
        field={@field} 
        type="number" 
        name={"draft[consumption_assumptions_#{@assumption.id}][#{@field |> Atom.to_string()}]"}
        value={Map.get(@assumption, @field)} 
        step={@step} 
        debounce="blur" 
      />
    """
  end
end
