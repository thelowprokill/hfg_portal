defmodule BnwPortalWeb.Budget.Home.Components.Assumptions.IncomeAssumptions do
  use BnwPortalWeb, :live_component

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :draft,    :map,     required: true
  attr :locked,   :boolean, required: true
  attr :f,        :map,     required: true
  def income(assigns) when not assigns.locked do
    ~H"""
      <div class="mx-8 my-4 w-full grid grid-cols-6">
        <!-- row 1 -->
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-center">As Fed</div>
        <div class="px-2 self-center justify-self-center">100% Dry</div>

        <!-- row 2 -->
        <div class="px-2 self-center justify-self-end">Avg Dry %</div>
        <div class="px-2 self-center justify-self-end"><.bnw_input f={@f} field={:avg_dry_100} type="percent" step="0.01" debounce="blur"/></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end">As Fed Per Ton Feed Sales Price</div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@f.params, "as_fed_sales", 0) %></div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@f.params, "as_fed_sales_100", 0) %></div>

        <!-- row 3 -->
        <div class="px-2 self-center justify-self-end">Avg Markup on Dry Feed</div>
        <div class="px-2 self-center justify-self-end"><.bnw_input f={@f} field={:avg_feed_markup} type="money" step="0.01" debounce="blur"/></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end">As Fed Per Ton Feed Cost of Sales</div>
        <div class="px-2 self-center justify-self-end"><.bnw_input f={@f} field={:as_fed_cost}     type="money" step="0.01" debounce="blur"/></div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@f.params, "as_fed_cost_100", 0) %></div>

        <!-- row 4 -->
        <div class="px-2 self-center justify-self-end">Annual Interest Income</div>
        <div class="px-2 self-center justify-self-end"><.bnw_input f={@f} field={:annual_interest_income} type="money" debounce="blur"/></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>

        <!-- row 5 -->
        <div class="px-2 self-center justify-self-end">Med Costs Per Head Day</div>
        <div class="px-2 self-center justify-self-end"><.bnw_input f={@f} field={:med_cost_per_day} type="money" step="0.0001" debounce="blur"/></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>

        <!-- row 6 -->
        <div class="px-2 self-center justify-self-end">Med Sales Per Head Day</div>
        <div class="px-2 self-center justify-self-end"><.bnw_input f={@f} field={:med_sales_per_day} type="money" step="0.0001" debounce="blur"/></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>


      </div>
    """
  end

  def income(assigns) do
    ~H"""
      <div class="mx-8 my-4 w-full grid grid-cols-6">
        <!-- row 1 -->
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-center">As Fed</div>
        <div class="px-2 self-center justify-self-center">100% Dry</div>

        <!-- row 2 -->
        <div class="px-2 self-center justify-self-end">Avg Dry </div>
        <div class="px-2 self-center justify-self-start"><%= Map.get(@draft, :avg_dry_100, 0) %>%</div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end">As Fed Per Ton Feed Sales Price</div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@draft, :as_fed_sales, 0) %></div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@draft, :as_fed_sales_100, 0) %></div>

        <!-- row 3 -->
        <div class="px-2 self-center justify-self-end">Avg Markup on Dry Feed</div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@draft, :avg_feed_markup, 0) %></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end">As Fed Per Ton Feed Cost of Sales</div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@draft, :as_fed_cost, 0) %></div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@draft, :as_fed_cost_100, 0) %></div>

        <!-- row 4 -->
        <div class="px-2 self-center justify-self-end">Annual Interest Income</div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@draft, :annual_interest_income, 0) %></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>

        <!-- row 5 -->
        <div class="px-2 self-center justify-self-end">Med Costs Per Head Day</div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@draft, :med_cost_per_day, 0) %></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>

        <!-- row 6 -->
        <div class="px-2 self-center justify-self-end">Med Sales Per Head Day</div>
        <div class="px-2 self-center justify-self-start">$<%= Map.get(@draft, :med_sales_per_day, 0) %></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
        <div class="px-2 self-center justify-self-end"></div>
      </div>
    """
  end
end
