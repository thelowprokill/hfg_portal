defmodule BnwPortalWeb.Budget.Home.Components.Assumptions do
  use BnwPortalWeb, :live_component

  alias BnwPortalWeb.Budget.Home.Components.Assumptions.{
    ConsumptionAssumptions,
    IncomeAssumptions,
    MonthlyData,
    MiscIncome,
  }

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,               :map,     required: true
  attr :draft,           :map,     required: true
  attr :locked,          :boolean, required: true
  attr :selected,        :map,     required: true
  attr :animal_sexes,    :list,    required: true
  attr :animal_types,    :list,    required: true
  attr :variable_inputs, :list,    required: true
  def assumptions(assigns) do
    ~H"""
      <div class="w-[97%] pr-8 mr-8">
        <div class="p-1">
          <div class="p-1 w-full flex">
            <.bnw_button phx-value-id={@draft.id} phx_click="select_consumption">Consumption Assumptions</.bnw_button>
            <div class="flex-grow"></div>
            <.bnw_icon bnw_icon={if @selected.consumption, do: "minus", else: "plus"} />
          </div>
          <%= if @selected.consumption do %>
            <hr />
            <div class="mx-8 my-4" hidden={!@selected.consumption}>
              <ConsumptionAssumptions.consumption 
                f={@f} 
                draft={@draft} 
                locked={@locked}
                animal_sexes={@animal_sexes} 
                animal_types={@animal_types} 
              />
            </div>
          <% end %>
        </div>
        
        <div class="p-1">
          <div class="p-1 w-full flex">
            <.bnw_button phx-value-id={@draft.id} phx_click="select_income">Income Assumptions</.bnw_button>
            <div class="flex-grow"></div>
            <.bnw_icon bnw_icon={if @selected.income, do: "minus", else: "plus"} />
          </div>
          <hr />
          <%= if @selected.income do %>
            <div class="mx-8 my-4" hidden={!@selected.income}>
              <IncomeAssumptions.income f={@f} draft={@draft} locked={@locked} />
            </div>
          <% end %>
        </div>
        
        <div class="p-1">
          <div class="p-1 w-full flex">
            <.bnw_button phx-value-id={@draft.id} phx_click="select_monthly_data">Monthly Data</.bnw_button>
            <div class="flex-grow"></div>
            <.bnw_icon bnw_icon={if @selected.monthly_data, do: "minus", else: "plus"} />
          </div>
          <hr />
          <%= if @selected.monthly_data do %>
            <div class="mx-8 my-4" hidden={!@selected.monthly_data}>
              <MonthlyData.monthly_data f={@f} draft={@draft} locked={@locked} animal_types={@animal_types} variable_inputs={@variable_inputs} />
            </div>
          <% end %>
        </div>
        
        <div class="p-1">
          <div class="p-1 w-full flex">
            <.bnw_button phx-value-id={@draft.id} phx_click="select_misc_income">Misc Income</.bnw_button>
            <div class="flex-grow"></div>
            <.bnw_icon bnw_icon={if @selected.misc_income, do: "minus", else: "plus"} />
          </div>
          <hr />
          <%= if @selected.misc_income do %>
            <div class="mx-8 my-4" hidden={!@selected.misc_income}>
              <MiscIncome.misc_income f={@f} draft={@draft} locked={@locked} variable_inputs={@variable_inputs} />
            </div>
          <% end %>
        </div>
      </div>
    """
  end
end
