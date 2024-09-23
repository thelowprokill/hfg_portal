defmodule BnwPortalWeb.Budget.Home.Components.Planning.VariablePlanningLine do
  use BnwPortalWeb, :live_component

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,                  :map,     required: true
  attr :expand,             :boolean, required: true
  attr :draft,              :map,     required: true
  attr :locked,             :boolean, required: true
  attr :department_account, :map,     required: true
  attr :variable_inputs,    :list,    required: true
  def variable_planning_line(assigns) when assigns.expand do
    ~H"""
      <div class="p-1">
        <.bnw_table id={"variable_planning_lines_table_#{@department_account.id}"} height="40vh" load_more={false}>
          <:header>
            <th></th>
            <th>Variable Input</th>
            <th>Amount</th>
            <th>Total</th>
            <th>Comment</th>
          </:header>
          <.variable_planning_line_details f={@f} draft={@draft} locked={@locked} department_account={@department_account} variable_inputs={@variable_inputs |> Enum.reject(&(&1.misc))} />
        </.bnw_table>

        <%= if !@locked do %>
          <.bnw_button_primary_pill
            phx-value-department_account_id={@department_account.id}
            phx_click="new_vpl">
            New Variable Planning Line
          </.bnw_button_primary_pill>
        <% end %>
      </div>
    """
  end
  def variable_planning_line(assigns) do
    ~H"""
      <div hidden="true">
        <%= for vpl <- @draft.variable_planning_lines |> Enum.filter(&(&1.department_account_id == @department_account.id)) do %>
          <.bnw_input_hidden f={@f} field={:id}
            value={vpl.id}
            name={"draft[variable_planning_lines_#{@department_account.id}_#{vpl.id}][id]"} />

          <.bnw_input_hidden f={@f} field={:department_account_id} value={@department_account.id} name={"draft[variable_planning_lines_#{@department_account.id}_#{vpl.id}][department_account_id]"} />

          <.bnw_input_hidden f={@f} field={:amount}  value={vpl.amount}  name={"draft[variable_planning_lines_#{@department_account.id}_#{vpl.id}][amount]"}  />
          <.bnw_input_hidden f={@f} field={:total}   value={vpl.total}   name={"draft[variable_planning_lines_#{@department_account.id}_#{vpl.id}][total]"}  />
          <.bnw_input_hidden f={@f} field={:comment} value={vpl.comment} name={"draft[variable_planning_lines_#{@department_account.id}_#{vpl.id}][comment]"}  />
        <% end %>
      </div>
    """
  end

  attr :f,                  :map,     required: true
  attr :draft,              :map,     required: true
  attr :locked,             :boolean, required: true
  attr :department_account, :map,     required: true
  attr :variable_inputs,    :list,    required: true
  def variable_planning_line_details(assigns) when not assigns.locked do
    ~H"""
      <div>
        <%= for vpl <- @draft.variable_planning_lines |> Enum.filter(&(&1.department_account_id == @department_account.id)) do %>
          <tr>
            <td><.bnw_button_delete phx-value-id={vpl.id} phx-value-existing={1} phx_click="delete_vpl" /></td>

            <td>
              <.bnw_input_hidden f={@f} field={:id}
                value={vpl.id}
                name={"draft[variable_planning_lines_#{@department_account.id}_#{vpl.id}][id]"} />

              <.bnw_input_hidden f={@f} field={:department_account_id} value={@department_account.id} name={"draft[variable_planning_lines_#{@department_account.id}_#{vpl.id}][department_account_id]"} />

              <.bnw_input_hidden f={@f} field={:variable_input_id}
                value={ Enum.find((@variable_inputs), %{}, &(&1.name == vpl.variable_input_name)) |> Map.get(:id) }
                name={"draft[variable_planning_lines_#{@department_account.id}_#{vpl.id}][variable_input_id]"} />

              <.make_input
                f={@f}
                field={:variable_input_name}
                type="select"
                data={vpl}
                list={Enum.map([%{name: "Head Days"}, %{name: "Tons Fed"}] ++ @variable_inputs, &([key: &1.name, value: &1.name]))}
                department_account={@department_account}
              />
            </td>
            <td>
              <.make_input
                f={@f}
                field={:amount}
                data={vpl}
                display_name="Amount"
                department_account={@department_account}
                step="0.0001"
              />
            </td>
            <td class="px-4"><%= vpl |> Map.get(:total, 0) |> Number.Currency.number_to_currency(precision: 2) %></td>
            <td>
              <.make_input
                f={@f}
                field={:comment}
                type="text"
                data={vpl}
                display_name="Comment"
                department_account={@department_account}
              />
            </td>
          </tr>
        <% end %>
      </div>
    """
  end

  def variable_planning_line_details(assigns) do
    ~H"""
      <div>
        <%= for vpl <- @draft.variable_planning_lines |> Enum.filter(&(&1.department_account_id == @department_account.id)) do %>
          <tr>
            <td></td>
            <td><%= vpl.variable_input_name %></td>
            <td><%= vpl.amount |> Number.Currency.number_to_currency %></td>
            <td><%= vpl.total  |> Number.Currency.number_to_currency %></td>
            <td><%= vpl.comment %></td>
          </tr>
        <% end %>
      </div>
    """
  end

  attr :f,                  :map,     required: true
  attr :field,              :any,     required: true
  attr :type,               :string,  default: "number"
  attr :data,               :map,     default: %{}
  attr :department_account, :map,     required: true
  attr :display_name,       :string,  default: ""
  attr :step,               :string,  default: "1"
  attr :list,               :list,    default: []
  defp make_input(assigns) do
    ~H"""
      <.bnw_input_naked
        f={@f}
        field={@field}
        type={@type}
        name={"draft[variable_planning_lines_#{@department_account.id}_#{@data.id}][#{@field |> Atom.to_string()}]"}
        display_name={@display_name}
        value={Map.get(@data, @field)}
        step={@step}
        list={@list}
        debounce="blur"
      />
    """
  end

  def calculate_total(draft, department_account_id) do
    draft.variable_planning_lines 
    |> Enum.filter(&(&1.department_account_id == department_account_id)) 
    |> Enum.map(&(&1.total))
    |> Enum.reduce(Decimal.new(0), fn x, acc -> Decimal.add(acc, x) end)
  end
end
