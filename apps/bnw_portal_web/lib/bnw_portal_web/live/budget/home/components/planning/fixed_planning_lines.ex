defmodule BnwPortalWeb.Budget.Home.Components.Planning.FixedPlanningLine do
  use BnwPortalWeb, :live_component

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,                  :map,     required: true
  attr :expand,             :boolean, required: true
  attr :draft,              :map,     required: true
  attr :locked,             :boolean, required: true
  attr :department_account, :map,     required: true
  def fixed_planning_line(assigns) when assigns.expand do
    ~H"""
      <div class="p-1">
        <.bnw_table id={"fixed_planning_lines_table_#{@department_account.id}"} height="40vh" load_more={false}>
          <:header>
            <th></th>
            <th>Amount</th>
            <th>Comment</th>
          </:header>
          <.fixed_planning_line_details f={@f} draft={@draft} locked={@locked} department_account={@department_account} />
        </.bnw_table>

        <%= if !@locked do %>
          <.bnw_button_primary_pill
            phx-value-department_account_id={@department_account.id}
            phx_click="new_fpl">
            New Fixed Planning Line
          </.bnw_button_primary_pill>
        <% end %>
      </div>
    """
  end

  def fixed_planning_line(assigns) do
    ~H"""
      <div hidden="true">
        <%= for fpl <- @draft.fixed_planning_lines |> Enum.filter(&(&1.department_account_id == @department_account.id)) do %>
          <.bnw_input_hidden f={@f} field={:id}
            value={fpl.id}
            name={"draft[fixed_planning_lines_#{@department_account.id}_#{fpl.id}][id]"} />

          <.bnw_input_hidden f={@f} field={:department_account_id} value={@department_account.id} name={"draft[fixed_planning_lines_#{@department_account.id}_#{fpl.id}][department_account_id]"} />

          <.bnw_input_hidden f={@f} field={:amount}  value={fpl.amount}  name={"draft[fixed_planning_lines_#{@department_account.id}_#{fpl.id}][amount]"}  />
          <.bnw_input_hidden f={@f} field={:comment} value={fpl.comment} name={"draft[fixed_planning_lines_#{@department_account.id}_#{fpl.id}][comment]"}  />
        <% end %>
      </div>
    """
  end

  attr :f,                  :map,     required: true
  attr :draft,              :map,     required: true
  attr :locked,             :boolean, required: true
  attr :department_account, :map,     required: true
  def fixed_planning_line_details(assigns) when not assigns.locked do
    ~H"""
      <div>
        <%= for fpl <- @draft.fixed_planning_lines |> Enum.filter(&(&1.department_account_id == @department_account.id)) do %>
          <tr>
            <td><.bnw_button_delete phx-value-id={fpl.id} phx-value-existing={1} phx_click="delete_fpl" /></td>

            <td>
              <.bnw_input_hidden f={@f} field={:id}
                value={fpl.id}
                name={"draft[fixed_planning_lines_#{@department_account.id}_#{fpl.id}][id]"} />

              <.bnw_input_hidden f={@f} field={:department_account_id} value={@department_account.id} name={"draft[fixed_planning_lines_#{@department_account.id}_#{fpl.id}][department_account_id]"} />

              <.make_input
                f={@f}
                field={:amount}
                data={fpl}
                display_name="Amount"
                department_account={@department_account}
                step="0.0001"
              />
            </td>
            <td>
              <.make_input
                f={@f}
                field={:comment}
                type="text"
                data={fpl}
                display_name="Comment"
                department_account={@department_account}
              />
            </td>
          </tr>
        <% end %>
      </div>
    """
  end

  def fixed_planning_line_details(assigns) do
    ~H"""
      <div>
        <%= for fpl <- @draft.fixed_planning_lines |> Enum.filter(&(&1.department_account_id == @department_account.id)) do %>
          <tr>
            <td></td>
            <td><%= fpl.amount %></td>
            <td><%= fpl.comment %></td>
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
  attr :step,               :string,  default:  "1"
  attr :list,               :list,    default:  []
  defp make_input(assigns) do
    ~H"""
      <.bnw_input_naked
        f={@f}
        field={@field}
        type={@type}
        name={"draft[fixed_planning_lines_#{@department_account.id}_#{@data.id}][#{@field |> Atom.to_string()}]"}
        display_name={@display_name}
        value={Map.get(@data, @field)}
        step={@step}
        list={@list}
        debounce="blur"
      />
    """
  end

  def calculate_total(draft, department_account_id) do
    draft.fixed_planning_lines
    |> Enum.filter(&(&1.department_account_id == department_account_id))
    |> Enum.map(&(&1.amount))
    |> Enum.reduce(Decimal.new(0), fn x, acc -> Decimal.add(acc, x) end)
  end
end
