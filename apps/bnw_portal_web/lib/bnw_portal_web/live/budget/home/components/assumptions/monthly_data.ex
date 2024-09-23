defmodule BnwPortalWeb.Budget.Home.Components.Assumptions.MonthlyData do
  use BnwPortalWeb, :live_component

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,               :map,     required: true
  attr :draft,           :map,     required: true
  attr :locked,          :boolean, required: true
  attr :animal_types,    :list,    required: true
  attr :variable_inputs, :list,    required: true
  def monthly_data(assigns) do
    ~H"""
      <div class="my-4">
        <.bnw_table id={"monthly_data_#{@draft.id}"} height="40vh" load_more={false}>
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
            <th class="p-2" style={"min-width: #{if @draft.locked, do: "20px", else: "100px"};"}>Total</th>
          </:header>
          <%= for {animal_type, i} <- @animal_types |> Enum.with_index do %>
            <.item 
              f={@f} 
              key="assumption_population_totals"
              draft={@draft} 
              locked={@locked}
              animal_type={animal_type}
              variable_input={nil} 
              data={Enum.find(@draft.assumption_population_totals, %{new: true, id: -1 * (i + 1)}, &(&1.animal_type_id == animal_type.id))} 
            />
          <% end %>
          <.total_head f={@f} draft={@draft} index={-1 * (1 + length(@animal_types))} />
          <.head_days  f={@f} draft={@draft} index={-1 * (2 + length(@animal_types))} />
          <.tons_fed   f={@f} draft={@draft} index={-1 * (3 + length(@animal_types))} />
          <%= for {variable_input, i} <- @variable_inputs |> Enum.reject(&(&1.misc)) |> Enum.with_index do %>
            <.item 
              f={@f} 
              key="assumption_commodity_totals"
              draft={@draft} 
              locked={@locked}
              animal_type={nil}
              variable_input={variable_input} 
              data={Enum.find(@draft.assumption_commodity_totals, %{new: true, id: -1 * (i + 4 + length(@animal_types))}, &(&1.variable_input_id == variable_input.id))} 
            />
          <% end %>
        </.bnw_table>
      </div>
    """
  end

  attr :f,     :map,     required: true
  attr :draft, :map,     required: true
  attr :index, :integer, required: true
  defp total_head(assigns) do
    ~H"""
      <tr>
        <% data = @draft.assumption_population_totals |> Enum.find(&(&1.is_total == true)) %>

        <td class="p-2">Total Head</td>
        <%= if data do %>
          <.bnw_input_hidden f={@f} field={:id}       name={"draft[assumption_population_totals_#{data.id}][id]"}    value={data.id} />
          <.bnw_input_hidden f={@f} field={:is_total} name={"draft[assumption_population_totals_#{data.id}][is_total]"} value={1} />
        <% end %>
        <%= for month <- 1..12 do %>
          <td class="p-2">
            <%= 
              cond do
                data -> Map.get(data, "month_#{month}" |> String.to_atom) 
                true -> 0
              end
              |> Number.Delimit.number_to_delimited(precision: 0) 
            %>
          </td>
        <% end %>
        <td class="p-2">
          <%= Enum.reduce(1..12, 0, fn month, acc ->
            cond do
              data -> Map.get(data, "month_#{month}" |> String.to_atom, 0)
              true -> 0
            end + acc
          end) |> Number.Delimit.number_to_delimited(precision: 0) %>
        </td>
      </tr>
    """
  end

  attr :f,     :map,     required: true
  attr :draft, :map,     required: true
  attr :index, :integer, required: true
  defp head_days(assigns) do
    ~H"""
      <% data = @draft.assumption_commodity_totals |> Enum.find(%{id: -1}, &(&1.variable_input_name == "Head Days")) %>
      <tr>
        <td class="p-2">Head Days</td>
        <.bnw_input_hidden f={@f} field={:id}    name={"draft[assumption_commodity_totals_#{data.id}][id]"}    value={data.id} />
        <.bnw_input_hidden f={@f} field={:total} name={"draft[assumption_commodity_totals_#{data.id}][total]"} value={1} />
        <.bnw_input_hidden f={@f} field={:variable_input_name} name={"draft[assumption_commodity_totals_#{data.id}][variable_input_name]"} value="Head Days" />
        <%= for month <- 1..12 do %>
          <td class="p-2"><%= Map.get(data, "month_#{month}" |> String.to_atom) |> Number.Delimit.number_to_delimited %></td>
        <% end %>
        <td class="p-2">
          <%= Map.get(data, :total) |> Number.Delimit.number_to_delimited(precision: 2) %>
        </td>
      </tr>
    """
  end

  attr :f,     :map,     required: true
  attr :draft, :map,     required: true
  attr :index, :integer, required: true
  defp tons_fed(assigns) do
    ~H"""
      <% data = @draft.assumption_commodity_totals |> Enum.find(%{id: @index}, &(&1.variable_input_name == "Tons Fed")) %>
      <tr>
        <td class="p-2">Tons Fed</td>
        <.bnw_input_hidden f={@f} field={:id}    name={"draft[assumption_commodity_totals_#{data.id}][id]"}    value={data.id} />
        <.bnw_input_hidden f={@f} field={:total} name={"draft[assumption_commodity_totals_#{data.id}][total]"} value={1} />
        <.bnw_input_hidden f={@f} field={:variable_input_name} name={"draft[assumption_commodity_totals_#{data.id}][variable_input_name]"} value="Tons Fed" />
        <%= for month <- 1..12 do %>
          <td class="p-2">
            <%= Map.get(data, "month_#{month}" |> String.to_atom) |> Number.Delimit.number_to_delimited() %>
          </td>
        <% end %>
        <td class="p-2">
          <%= Map.get(data, :total) |> Number.Delimit.number_to_delimited(precision: 2) %>
        </td>
      </tr>
    """
  end

  attr :f,               :map,     required: true
  attr :key,             :string,  required: true
  attr :animal_type,     :any,     required: true
  attr :variable_input,  :any,     required: true
  attr :draft,           :map,     required: true
  attr :locked,          :boolean, required: true
  attr :data,            :map,     required: true
  defp item(assigns) when assigns.locked == false do
    ~H"""
      <tr>
        <.bnw_input_hidden f={@f} field={:id}    name={"draft[#{@key}_#{@data.id}][id]"}    value={@data.id} />
        <.bnw_input_hidden f={@f} field={:index} name={"draft[#{@key}_#{@data.id}][index]"} value={@data.id} />
        <%= if @animal_type do %>
          <.bnw_input_hidden f={@f} field={:variable_input_id} name={"draft[#{@key}_#{@data.id}][animal_type_id]"} value={@animal_type.id} />
        <% end %>
        <%= if @variable_input do %>
          <.bnw_input_hidden f={@f} field={:variable_input_id}   name={"draft[#{@key}_#{@data.id}][variable_input_id]"}   value={@variable_input.id} />
          <.bnw_input_hidden f={@f} field={:variable_input_name} name={"draft[#{@key}_#{@data.id}][variable_input_name]"} value={@variable_input.name} />
        <% end %>
        <td class="p-2">
          <%= cond do
            @animal_type    -> @animal_type.name
            @variable_input -> @variable_input.name
            true -> ""
          end %>
        </td>
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
        <td class="p-2"><%= @data |> Map.get(:total, 0) |> Number.Delimit.number_to_delimited() %></td>
      </tr>
    """
  end

  defp item(assigns) do
    ~H"""
      <%
        curr = cond do
          @animal_type    -> @draft.assumption_population_totals |> Enum.find(%{}, &(&1.animal_type_id      == @animal_type.id   ))
          @variable_input -> @draft.assumption_commodity_totals  |> Enum.find(%{}, &(&1.variable_input_name == @variable_input.name))
          true -> %{}
        end
      %>
      <tr>
        <td class="p-2">
          <%= cond do
            @animal_type    -> @animal_type.name
            @variable_input -> @variable_input.name
            true -> ""
          end %>
        </td>
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
        <td class="p-2"><%= curr |> Map.get(:total, 0) |> Number.Delimit.number_to_delimited() %></td>
      </tr>
    """
  end

  attr :f,     :map,    required: true
  attr :key,   :string, required: true
  attr :field, :any,    required: true
  attr :data,  :map,    required: true
  defp make_input(assigns) do
    ~H""" 
      <% 
        params = @f.params |> Map.get(@key, []) |> Enum.find(%{}, &(Map.get(&1, "index") |> String.to_integer() == @data.id)) 
        s_field = Atom.to_string(@field)
        value = Map.get(params, s_field, Map.get(@data, @field, 0))
      %>
      <.bnw_input_naked 
        f={@f} 
        field={@field} 
        type={"number"} 
        name={"draft[#{@key}_#{@data.id}][#{s_field}]"} 
        value={value} 
        step={if @key == "misc_income", do: "0.01", else: "1"} 
        debounce="blur"
      />
    """
  end
end

