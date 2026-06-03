defmodule HfgPortalWeb.Helpers.Table do
  use Phoenix.LiveView

  import HfgPortalWeb.Helpers.Buttons
  import HfgPortalWeb.Helpers.Inputs
  import HfgPortalWeb.Helpers.Utility

  attr :id,               :string,  default: "table"
  attr :update_direction, :string,  default: "replace"
  attr :height,           :string,  default: "75vh"
  attr :width,            :string,  default: "100%"
  attr :load_more,        :boolean, default: true
  attr :left_offset_1,    :string,  default: "0"
  attr :left_offset_2,    :string,  default: "0"
  attr :left_offset_3,    :string,  default: "0"
  attr :right_offset_1,   :string,  default: "0"
  attr :right_offset_2,   :string,  default: "0"
  attr :right_offset_3,   :string,  default: "0"
  slot :inner_block,      required: true
  slot :header,           required: true, doc: "This is the header intformation for the table"
  def bnw_table(assigns) do
    ~H"""
    <div class="overflow-auto" style={"max-height: #{@height}; max-width: #{@width}"}>
      <table
        id={"table_#{@id}"}
        class="w-full table-auto text-left"
        phx-hook="sticky_columns_general"
        data-left_offset_1={@left_offset_1}
        data-left_offset_2={@left_offset_2}
        data-left_offset_3={@left_offset_3}
        data-right_offset_1={@right_offset_1}
        data-right_offset_2={@right_offset_2}
        data-right_offset_3={@right_offset_3}
      >
        <thead class="sticky top-0 font-medium dark:border-neutral-500">
          <tr class="bg-zinc-50 dark:bg-zinc-800"><%= render_slot(@header) %></tr>
          <tr class="bg-neutral-500">
            <th colspan="256"></th>
          </tr>
        </thead>
        <tbody id={"infinite_scroll_test_list_#{@id}"} phx-update={@update_direction}>
          <%= render_slot(@inner_block) %>
        </tbody>
      </table>
      <%= if @load_more do %><.bnw_button_load_more id={"infinite_scroll_button_#{@id}"}/><% end %>
    </div>
    """
  end

  attr :sticky, :integer, default:  0
  attr :right,  :integer, default:  0
  attr :pos,    :integer, default:  0
  slot :inner_block,      required: true
  def bnw_th(assigns) when assigns.sticky == 1, do: ~H'<th class={"p-2 table-sticky-head sticky-col-#{if @right == 1, do: "right", else: "left"}-#{@pos} bg-zinc-50 dark:bg-zinc-800"}><%= render_slot(@inner_block) %></th>'
  def bnw_th(assigns), do: ~H'<th class="p-2 bg-zinc-50 dark:bg-zinc-800"><%= render_slot(@inner_block) %></th>'

  attr :sticky, :integer, default:  0
  attr :right,  :integer, default:  0
  attr :pos,    :integer, default:  0
  slot :inner_block,      required: true
  def bnw_td(assigns) when assigns.sticky == 1, do: ~H'<td class={"px-2 table-sticky-body sticky-col-#{if @right == 1, do: "right", else: "left"}-#{@pos} bg-white dark:bg-zinc-900"}><%= render_slot(@inner_block) %></td>'
  def bnw_td(assigns), do: ~H'<td class="px-2 bg-white dark:bg-zinc-900"><%= render_slot(@inner_block) %></td>'

  attr :f,               :any, required: true
  attr :search_stack,    :any, required: true
  attr :sort_stack,      :any, required: true
  attr :field,           :any, required: true
  attr :starting_month,  :integer, default: 1
  attr :offset,          :integer, default: 1
  attr :keys,            :any,     default: []
  attr :list,            :any,     default: []
  attr :on_click_search, :string,  default: "search"
  attr :on_click_sort,   :string,  default: "sort"
  attr :on_close,        :string,  default: "hide_filter"
  attr :on_reset,        :string,  default: "reset_filters"
  attr :type,            :string,  default: "text"
  attr :width,           :string,  default: "150px"
  slot :inner_block,     required: true
  def bnw_table_header_filter(assigns) do
    ~H"""
      <% cur_search  = stack_tail(@search_stack) %>

      <% this_search    = @search_stack |> Enum.reject(&(&1.val == "")) |> Enum.find(nil, fn x -> x.field == @field end) %>
      <% {this_sort, i} = @sort_stack |> Enum.with_index |> Enum.find({nil, nil}, fn {x, _} -> x.field == @field end) %>

      <div class="p-2 flex" style={"min-width: #{@width};"}>
        <div><.bnw_button_icon bnw_icon="search" phx_click={@on_click_search} phx-value-field={@field} /></div>
        <div class="flex flex-col">
          <div class="flex">
            <p class="text-xs">
              <%= cond do %>
                <% this_search && this_search.val && @type == "month" -> %>
                  <%= "Search: #{get_month_name(this_search.val |> String.to_integer(), @starting_month, @offset)}" %>
                <% this_search && this_search.val -> %> <%= "Search: #{this_search.val}" %>
                <% true -> %> <%= nil %>
              <% end %>
            </p>
            <%= if this_search && this_search.val && this_search.val != "" do %>
              <.bnw_button_x phx_click={@on_reset} phx-value-field={@field} />
            <% end %>
          </div>
          <%= cond do %>
            <% cur_search && cur_search.field == @field && cur_search.show -> %>
              <div phx-click-away={@on_close}>
                <.bnw_input_hidden f={@f} field="field" value={@field} />
                <.bnw_input_naked value={if this_search, do: Map.get(this_search, :val)} {assigns} field="val" />
              </div>
            <% true -> %>
              <%= render_slot(@inner_block) %>
          <% end %>
        </div>
        <div class="flex flex-col">
          <%= cond do %>
            <% this_sort && this_sort.order == :asc -> %>
              <.bnw_button_icon bnw_icon={"chevron-up-solid"} phx_click={@on_click_sort} phx-value-field={@field} />
            <% this_sort && this_sort.order == :desc -> %>
              <.bnw_button_icon bnw_icon={"chevron-dn-solid"} phx_click={@on_click_sort} phx-value-field={@field} />
            <% true -> %>
              <.bnw_button_icon bnw_icon={"chevron-up-dn"} phx_click={@on_click_sort} phx-value-field={@field} />
          <% end %>
        </div>
        <%= if i do %>
          <div><%= i + 1 %></div>
        <% end %>
      </div>
    """
    #~H"""
    #  <% cur_search  = stack_tail(@search_stack) %>

    #  <% this_search    = @search_stack |> Enum.reject(&(&1.val == "")) |> Enum.find(nil, fn x -> x.field == @field end) %>
    #  <% {this_sort, i} = @sort_stack |> Enum.with_index |> Enum.find({nil, nil}, fn {x, _} -> x.field == @field end) %>

    #  <div class="p-2 grid grid-cols-12 justify-items-center" style={"min-width: #{@width};"}>

    #    <!-- 1 -->
    #    <div style="height: 1vh"></div>

    #    <!-- 2 -->
    #    <div class="col-span-10" style="height: 1vh">
    #      <div class="flex">
    #        <p class="text-xs">
    #          <%= cond do %>
    #            <%# this_search && this_search.val && @type == "drop_down" -> %>
    #              <%# "Search: #{get_drop_down_value(@list, @keys)}" %>
    #            <% this_search && this_search.val && @type == "month" -> %>
    #              <%= "Search: #{get_month_name(this_search.val |> String.to_integer(), @starting_month, @offset)}" %>
    #            <% this_search && this_search.val -> %> <%= "Search: #{this_search.val}" %>
    #            <% true -> %> <%= nil %>
    #          <% end %>
    #        </p>
    #        <%= if this_search && this_search.val && this_search.val != "" do %>
    #          <.bnw_button_x phx_click={@on_reset} phx-value-field={@field} />
    #        <% end %>
    #      </div>
    #    </div>

    #    <!-- 3 -->
    #    <div class="pb-3"style="height: 1vh">
    #        <.bnw_button_icon bnw_icon={"chevron-up#{if this_sort && this_sort.order == :asc, do: '-solid'}"} phx_click={@on_click_sort} phx-value-order="asc"  phx-value-field={@field} />
    #    </div>

    #    <!-- 4 -->
    #    <div style="height: 2vh"><.bnw_button_icon bnw_icon="search" phx_click={@on_click_search} phx-value-field={@field} /></div>

    #    <!-- 5 -->
    #    <div class="col-span-10" style="height: 2vh">
    #      <%= cond do %>
    #        <% cur_search && cur_search.field == @field && cur_search.show -> %>
    #          <div phx-click-away={@on_close}>
    #            <.bnw_input_hidden f={@f} field="field" value={@field} />
    #            <.bnw_input_naked {assigns} field="val" autofocus />
    #          </div>
    #        <% true -> %>
    #          <%= render_slot(@inner_block) %>
    #      <% end %>
    #    </div>

    #    <!-- 6 -->
    #    <div style="height: 2vh"><%= if i, do: i + 1 %></div>

    #    <!-- 7 -->
    #    <div style="height: 1vh"></div>

    #    <!-- 8 -->
    #    <div class="col-span-10" style="height: 1vh"></div>


    #    <!-- 9 -->
    #    <div style="height: 1vh">
    #        <.bnw_button_icon bnw_icon={"chevron-dn#{if this_sort && this_sort.order == :desc, do: '-solid'}"} phx_click={@on_click_sort} phx-value-order="desc"  phx-value-field={@field} />
    #    </div>
    #  </div>
    #"""
  end

  # make the compiler happy
  def render(assigns), do: ~H"<div>render</div>"
end
