defmodule BnwPortalWeb.Budget.Home.Components.DraftItem do
  use BnwPortalWeb, :live_component

  alias BnwPortalWeb.Budget.Home.Components.{
    Assumptions,
    Planning,
    MonthlyInputs,
    Reports,
  }

  # make the compiler happy
  @impl true
  def render(assigns), do: ~H"<div>render</div>"

  attr :f,                :map,     required: true
  attr :draft,            :map,     required: true
  attr :draft_type,       :map,     required: true
  attr :selected,         :map,     required: true
  attr :animal_sexes,     :list,    required: true
  attr :animal_types,     :list,    required: true
  attr :variable_inputs,  :list,    required: true
  attr :reports,          :list,    required: true
  attr :anim,             :map,     default: false
  attr :home_permissions, :list,    required: true
  attr :current_user,     :map,     required: true
  attr :admin,            :boolean, required: true
  def draft_item(assigns) do
    ~H"""
      <div>
        <div class="overflow-y-auto" style="max-height: 68vh;">
          <div style="width: 97%;">
            <div class="w-full">
              <%= if @draft.id == @selected.draft do %>
                <div class={"p-2 text-xl justify-self-center #{if @anim.loading, do: 'text-success-main'}"}>
                  <div class="flex-grow"/>
                  <%= @draft.name %>
                  <div class="flex-grow"/>
                </div>
                <%= if check_perm(["view", "edit"], @home_permissions, @selected, "assumptions", @current_user, @admin) do %>
                  <div class="p-1 w-full">
                    <div class="p-1 w-full flex">
                      <.bnw_button phx-value-id={@draft.id} phx_click="select_assumptions">Assumptions</.bnw_button>
                      <div class="flex-grow"></div>
                      <.bnw_icon bnw_icon={if @selected.assumptions, do: "minus", else: "plus"} />
                    </div>
                    <hr />
                    <%= if @selected.assumptions do %>
                      <div class="mx-8 my-4 w-full" hidden={!@selected.assumptions}>
                        <Assumptions.assumptions 
                          f={@f} 
                          draft={@draft} 
                          locked={@draft.locked || !check_perm(["edit"], @home_permissions, @selected, "assumptions", @current_user, @admin)}
                          selected={@selected} 
                          animal_sexes={@animal_sexes} 
                          animal_types={@animal_types} 
                          variable_inputs={@variable_inputs}
                        />
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%= if check_perm(["view", "edit"], @home_permissions, @selected, "planning", @current_user, @admin) && Map.get(@draft_type, :show_planning, false) do %>
                  <div class="p-1">
                    <div class="p-1 w-full flex">
                      <.bnw_button phx-value-id={@draft.id} phx_click="select_planning">Planning</.bnw_button>
                      <div class="flex-grow"></div>
                      <.bnw_icon bnw_icon={if @selected.planning, do: "minus", else: "plus"} />
                    </div>
                    <hr />
                    <%= if @selected.planning do %>
                      <div class="mx-8 my-4 w-full" hidden={!@selected.planning}>
                        <Planning.planning 
                          f={@f} 
                          draft={@draft} 
                          locked={@draft.locked || !check_perm(["edit"], @home_permissions, @selected, "planning", @current_user, @admin)}
                          selected={@selected} 
                          variable_inputs={@variable_inputs}
                        />
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%= if check_perm(["view", "edit"], @home_permissions, @selected, "monthly_inputs", @current_user, @admin) && Map.get(@draft_type, :show_monthly_inputs, false) do %>
                  <div class="p-1">
                    <div class="p-1 w-full flex">
                      <.bnw_button phx-value-id={@draft.id} phx_click="select_monthly_inputs">Monthly Inputs</.bnw_button>
                      <div class="flex-grow"></div>
                      <.bnw_icon bnw_icon={if @selected.monthly_inputs, do: "minus", else: "plus"} />
                    </div>
                    <hr />

                    <%= if @selected.monthly_inputs do %>
                      <div class="mx-8 my-4 w-full" hidden={!@selected.monthly_inputs}>
                        <MonthlyInputs.monthly_inputs 
                          f={@f} 
                          draft={@draft} 
                          locked={!check_perm(["edit"], @home_permissions, @selected, "monthly_inputs", @current_user, @admin)}
                          variable_inputs={@variable_inputs}
                        />
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%= if check_perm(["view"], @home_permissions, @selected, "reports", @current_user, @admin) && Map.get(@draft_type, :show_monthly_inputs, false) do %>
                  <div class="p-1">
                    <div class="p-1 w-full flex">
                      <.bnw_button phx-value-id={@draft.id} phx_click="select_reports">Reports</.bnw_button>
                      <div class="flex-grow"></div>
                      <.bnw_icon bnw_icon={if @selected.reports, do: "minus", else: "plus"} />
                    </div>
                    <hr />

                    <div class="mx-8 my-4 w-full" hidden={!@selected.reports}>
                      <Reports.reports reports={@reports} />
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    """
  end


  def check_perm(_perm, _perms, _company_id, _section, user, admin) when (user.dev_admin and user.admin_mode) or admin, do: true
  def check_perm(neded_perm, perms, selected, section, _user, _admin), do:
    perms
    |> Enum.filter(fn x -> 
      (
        ( # company level
          x.company_id == selected.company 
          && is_nil(x.location_id)
          && is_nil(x.company_budget_id)
          && is_nil(x.draft_type_id)
          && is_nil(x.draft_id)
        )
        #|| ( # location level
        #  x.company_id == selected.company
        #  && x.location_id == selected.location
        #  && is_nil(x.company_budget_id)
        #  && is_nil(x.draft_type_id)
        #  && is_nil(x.draft_id)
        #)
        || ( # company budget level
          x.company_id == selected.company
          #&& x.location_id == selected.location
          && (x.company_budget_id == selected.budget || selected.budget == 0)
          && is_nil(x.draft_type_id)
          && is_nil(x.draft_id)
        )
        || ( # draft type level
          x.company_id == selected.company
          #&& x.location_id == selected.location
          && is_nil(x.company_budget_id)
          && x.draft_type_id == selected.draft_type
          && is_nil(x.draft_id)
        )
        || ( # draft level
          x.company_id == selected.company
          #&& x.location_id == selected.location
          && is_nil(x.company_budget_id)
          && is_nil(x.draft_type_id)
          && x.draft_id == selected.draft
        )
      )
      && x.section == section
    end)
    |> Enum.map(&(&1.permission))
    |> Enum.uniq()
    |> Enum.any?(&(Enum.member?(neded_perm, &1)))
end
