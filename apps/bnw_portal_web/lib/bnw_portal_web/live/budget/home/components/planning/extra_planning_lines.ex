defmodule BnwPortalWeb.Budget.Home.Components.Planning.ExtraPlanningLine do
  use BnwPortalWeb, :live_component

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,                  :map,     required: true
  attr :expand,             :boolean, required: true
  attr :draft,              :map,     required: true
  attr :locked,             :boolean, required: true
  attr :department_account, :map,     required: true
  def extra_planning_line(assigns) when assigns.expand do
    ~H"""
      <div class="p-1">
        <.bnw_table id={"extra_planning_lines_table_#{@department_account.id}"} height="40vh" load_more={false}>
          <:header>
            <th></th>
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
            <th style={"min-width: #{if @locked, do: "20px", else: "100px"};"}>Total</th>
            <th style={"min-width: #{if @locked, do: "20px", else: "100px"};"}>Comment</th>
          </:header>
          <.extra_planning_line_details f={@f} draft={@draft} locked={@locked} department_account={@department_account} />
        </.bnw_table>

        <%= if !@locked do %>
          <.bnw_button_primary_pill
            phx-value-department_account_id={@department_account.id}
            phx_click="new_epl">
            New Extra Planning Line
          </.bnw_button_primary_pill>
        <% end %>
      </div>
    """
  end

  def extra_planning_line(assigns) do
    ~H"""
      <div hidden="true">
        <%= for epl <- @draft.extra_planning_lines |> Enum.filter(&(&1.department_account_id == @department_account.id)) do %>
          <.bnw_input_hidden f={@f} field={:id}
            value={epl.id}
            name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][id]"} />

          <.bnw_input_hidden f={@f} field={:department_account_id} value={@department_account.id} name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][department_account_id]"} />

          <.bnw_input_hidden f={@f} field={:month_1}  value={epl.month_1}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_1]"}  />
          <.bnw_input_hidden f={@f} field={:month_2}  value={epl.month_2}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_2]"}  />
          <.bnw_input_hidden f={@f} field={:month_3}  value={epl.month_3}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_3]"}  />
          <.bnw_input_hidden f={@f} field={:month_4}  value={epl.month_4}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_4]"}  />
          <.bnw_input_hidden f={@f} field={:month_5}  value={epl.month_5}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_5]"}  />
          <.bnw_input_hidden f={@f} field={:month_6}  value={epl.month_6}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_6]"}  />
          <.bnw_input_hidden f={@f} field={:month_7}  value={epl.month_7}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_7]"}  />
          <.bnw_input_hidden f={@f} field={:month_8}  value={epl.month_8}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_8]"}  />
          <.bnw_input_hidden f={@f} field={:month_9}  value={epl.month_9}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_9]"}  />
          <.bnw_input_hidden f={@f} field={:month_10} value={epl.month_10} name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_10]"} />
          <.bnw_input_hidden f={@f} field={:month_11} value={epl.month_11} name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_11]"} />
          <.bnw_input_hidden f={@f} field={:month_12} value={epl.month_12} name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][month_12]"} />
          <.bnw_input_hidden f={@f} field={:comment}  value={epl.comment}  name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][comment]"}  />
        <% end %>
      </div>
    """
  end

  attr :f,                  :map,     required: true
  attr :draft,              :map,     required: true
  attr :locked,             :boolean, required: true
  attr :department_account, :map,     required: true
  def extra_planning_line_details(assigns) when not assigns.locked do
    ~H"""
      <div>
        <%= for epl <- @draft.extra_planning_lines |> Enum.filter(&(&1.department_account_id == @department_account.id)) do %>
          <tr>
            <td>
              <.bnw_input_hidden f={@f} field={:id}
                value={epl.id}
                name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][id]"} />

              <.bnw_input_hidden f={@f} field={:department_account_id} value={@department_account.id} name={"draft[extra_planning_lines_#{@department_account.id}_#{epl.id}][department_account_id]"} />
              <.bnw_button_delete phx-value-id={epl.id} phx-value-existing={1} phx_click="delete_epl" />
            </td>

            <td><.make_input f={@f} field={:month_1}  data={epl} display_name="Month 1"  department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_2}  data={epl} display_name="Month 2"  department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_3}  data={epl} display_name="Month 3"  department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_4}  data={epl} display_name="Month 4"  department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_5}  data={epl} display_name="Month 5"  department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_6}  data={epl} display_name="Month 6"  department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_7}  data={epl} display_name="Month 7"  department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_8}  data={epl} display_name="Month 8"  department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_9}  data={epl} display_name="Month 9"  department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_10} data={epl} display_name="Month 10" department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_11} data={epl} display_name="Month 11" department_account={@department_account} /></td>
            <td><.make_input f={@f} field={:month_12} data={epl} display_name="Month 12" department_account={@department_account} /></td>
            <td><%= epl |> Map.get(:total) |> Number.Currency.number_to_currency() %></td>
            <td>
              <.make_input
                f={@f}
                field={:comment}
                type="text"
                data={epl}
                display_name="Comment"
                department_account={@department_account}
              />
            </td>
          </tr>
        <% end %>
      </div>
    """
  end

  def extra_planning_line_details(assigns) do
    ~H"""
      <div>
        <%= for epl <- @draft.extra_planning_lines |> Enum.filter(&(&1.department_account_id == @department_account.id)) do %>
          <tr>
            <td></td>
            <td><%= epl.month_1  %></td>
            <td><%= epl.month_2  %></td>
            <td><%= epl.month_3  %></td>
            <td><%= epl.month_4  %></td>
            <td><%= epl.month_5  %></td>
            <td><%= epl.month_6  %></td>
            <td><%= epl.month_7  %></td>
            <td><%= epl.month_8  %></td>
            <td><%= epl.month_9  %></td>
            <td><%= epl.month_10 %></td>
            <td><%= epl.month_11 %></td>
            <td><%= epl.month_12 %></td>
            <td><%= epl.total    %></td>
            <td><%= epl.comment  %></td>
          </tr>
        <% end %>
      </div>
    """
  end

  attr :f,                  :map,     required: true
  attr :field,              :any,     required: true
  attr :type,               :string,  default:  "number"
  attr :data,               :map,     default:  %{}
  attr :department_account, :map,     required: true
  attr :display_name,       :string,  default:  ""
  attr :step,               :string,  default:  "0.01"
  attr :list,               :list,    default:  []
  defp make_input(assigns) do
    ~H"""
      <.bnw_input_naked
        f={@f}
        field={@field}
        type={@type}
        name={"draft[extra_planning_lines_#{@department_account.id}_#{@data.id}][#{@field |> Atom.to_string()}]"}
        display_name={@display_name}
        value={Map.get(@data, @field)}
        step={@step}
        list={@list}
        debounce="blur"
      />
    """
  end

  def calculate_total(draft, department_account_id) do
    draft.extra_planning_lines
    |> Enum.filter(&(&1.department_account_id == department_account_id))
    |> Enum.map(&(&1.total))
    |> Enum.reduce(Decimal.new(0), fn x, acc -> Decimal.add(acc, x) end)
  end
end
