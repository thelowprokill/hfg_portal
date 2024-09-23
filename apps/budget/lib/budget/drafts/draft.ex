defmodule Budget.Drafts.Draft do
  use Ecto.Schema
  import Ecto.Changeset

  alias Budget.{
    Companies.CompanyBudget,
    Companies.DraftType,
    Drafts.AssumptionPopulationTotal,
    Drafts.AssumptionCommodityTotal,
    Drafts.ConsumptionAssumption,
    Drafts.ExtraPlanningLine,
    Drafts.FixedPlanningLine,
    Drafts.MiscIncome,
    Drafts.MonthlyInput,
    Drafts.VariablePlanningLine,
  }

  prefix = case Mix.env do
    :dev   -> "bnw_portal_budget_dev"
    :test  -> "bnw_portal_budget_test"
    :trial -> "bnw_portal_budget_trial"
    _      -> "bnw_portal_budget"
  end
  @schema_prefix prefix

  schema "drafts" do
    field :name,                   :string
    field :locked,                 :boolean, default: false
    field :year,                   :integer, default: DateTime.utc_now().year() + 1
    field :starting_month,         :integer, virtual: true
    field :start_date,             :date
    field :avg_dry_100,            :decimal, default: 0
    field :avg_feed_markup,        :decimal, default: 0
    field :as_fed_sales,           :decimal, default: 0
    field :as_fed_sales_100,       :decimal, default: 0
    field :as_fed_cost,            :decimal, default: 0
    field :as_fed_cost_100,        :decimal, default: 0
    field :annual_interest_income, :integer, default: 0
    field :med_cost_per_day,       :decimal, default: 0
    field :med_sales_per_day,      :decimal, default: 0

    belongs_to :company_budget,      CompanyBudget
    belongs_to :draft_type,          DraftType
    belongs_to :previous_year_draft, __MODULE__

    has_many :consumption_assumptions,      ConsumptionAssumption,     on_delete: :delete_all, on_replace: :delete
    has_many :assumption_population_totals, AssumptionPopulationTotal, on_delete: :delete_all, on_replace: :delete
    has_many :assumption_commodity_totals,  AssumptionCommodityTotal,  on_delete: :delete_all, on_replace: :delete
    has_many :misc_incomes,                 MiscIncome,                on_delete: :delete_all, on_replace: :delete
    has_many :extra_planning_lines,         ExtraPlanningLine,         on_delete: :delete_all, on_replace: :delete
    has_many :fixed_planning_lines,         FixedPlanningLine,         on_delete: :delete_all, on_replace: :delete
    has_many :variable_planning_lines,      VariablePlanningLine,      on_delete: :delete_all, on_replace: :delete
    has_many :monthly_inputs,               MonthlyInput,              on_delete: :delete_all, on_replace: :delete

    timestamps()
  end

  def changeset(draft, attrs \\ %{}) do
    draft
    |> cast(attrs, [
      :name,
      :year,
      :locked,
      :starting_month,
      :start_date,
      :avg_dry_100,
      :avg_feed_markup,
      :as_fed_sales,
      :as_fed_sales_100,
      :as_fed_cost,
      :as_fed_cost_100,
      :annual_interest_income,
      :med_cost_per_day,
      :med_sales_per_day,
      :company_budget_id,
      :draft_type_id,
      :previous_year_draft_id
    ])
    |> cast_association(:consumption_assumptions,      attrs, &ConsumptionAssumption.changeset/2)
    |> cast_association(:assumption_population_totals, attrs, &AssumptionPopulationTotal.changeset/2)
    |> cast_association(:assumption_commodity_totals,  attrs, &AssumptionCommodityTotal.changeset/2)
    |> cast_association(:misc_incomes,                 attrs, &MiscIncome.changeset/2)
    |> cast_association(:variable_planning_lines,      attrs, &VariablePlanningLine.changeset/2)
    |> cast_association(:fixed_planning_lines,         attrs, &FixedPlanningLine.changeset/2)
    |> cast_association(:extra_planning_lines,         attrs, &ExtraPlanningLine.changeset/2)
    |> cast_association(:monthly_inputs,               attrs, &MonthlyInput.changeset/2)
    |> set_start_date()
    |> validate_required([:name, :year, :start_date])
    |> unique_constraint(:name, name: :drafts_unique_index)
    |> calc_total_head()
    |> calc_head_days()
    |> calc_tons_fed()
    |> calc_ca_dmi_total()
    |> calc_variable_planning_total()
    |> calc_extra_planning_total()
    |> calc_assumption_population_totals()
    |> calc_assumption_commodity_totals()
    |> income_statements_calc()
  end

  defp cast_association(changeset, assoc, attrs, func) do
    cond do
      Map.get(attrs, assoc |> Atom.to_string, []) != [] -> cast_assoc(changeset, assoc, with: func)
      true -> changeset
    end
  end


  defp set_start_date(changeset) do
    start_date     = get_field(changeset, :start_date)
    starting_month = get_field(changeset, :starting_month)
    year           = get_field(changeset, :year)

    cond do
      is_nil(start_date) && starting_month && year -> 
        put_change(changeset, :start_date, Date.new!(year, starting_month, 1))
      true -> changeset
    end
  end

  defp calc_ca_dmi_total(changeset) do
    consumption_assumptions = get_assoc(changeset, :consumption_assumptions)

    cond do
      consumption_assumptions -> 
        consumption_assumptions = Enum.map(consumption_assumptions, fn ca ->
          total = Enum.reduce(1..12, Decimal.new(0), fn month, acc -> Decimal.add(get_field(ca, "month_#{month}" |> String.to_atom), acc) end)
          put_change(ca, :total, total)
        end)
        put_assoc(changeset, :consumption_assumptions, consumption_assumptions)
      true -> changeset
    end
  end

  defp calc_variable_planning_total(changeset) do
    vpl = get_assoc(changeset, :variable_planning_lines)
    act = get_assoc(changeset, :assumption_commodity_totals)

    cond do
      vpl && act ->
        vpl = Enum.map(vpl, fn vpl ->
          act = Enum.find(act, fn act -> get_field(act, :variable_input_name) == get_field(vpl, :variable_input_name) end)
          cond do
            is_nil(act) -> vpl
            true -> put_change(vpl, :total, get_field(vpl, :amount) |> Decimal.mult(get_field(act, :total)))
          end
        end)

        changeset
        |> put_assoc(:variable_planning_lines, vpl)
      true -> changeset
    end
  end

  defp calc_extra_planning_total(changeset) do
    epl = get_assoc(changeset, :extra_planning_lines)

    cond do
      epl ->
        epl = Enum.map(epl, fn epl ->
          put_change(epl, :total, Enum.reduce(1..12, Decimal.new(0), fn month, acc -> Decimal.add(get_field(epl, "month_#{month}" |> String.to_atom), acc) end))
        end)

        changeset
        |> put_assoc(:extra_planning_lines, epl)
      true -> changeset
    end
  end

  defp calc_assumption_population_totals(changeset) do
    apt = get_assoc(changeset, :assumption_population_totals)

    cond do
      apt ->
        apt = Enum.map(apt, fn apt ->
          put_change(apt, :total, Enum.reduce(1..12, 0, fn month, acc -> get_field(apt, "month_#{month}" |> String.to_atom) + acc end))
        end)

        changeset
        |> put_assoc(:assumption_population_totals, apt)
      true -> changeset
    end
  end

  defp calc_assumption_commodity_totals(changeset) do
    act = get_assoc(changeset, :assumption_commodity_totals)

    cond do
      act ->
        act = Enum.map(act, fn act ->
          put_change(act, :total, Enum.reduce(1..12, Decimal.new(0), fn month, acc -> Decimal.add(get_field(act, "month_#{month}" |> String.to_atom), acc) end))
        end)

        changeset
        |> put_assoc(:assumption_commodity_totals, act)

      true -> changeset
    end
  end

  defp income_statements_calc(changeset) do
    avg_dry = get_field(changeset, :avg_dry_100)
    as_fed_sales = get_field(changeset, :avg_feed_markup)

    cond do
      avg_dry && as_fed_sales ->
        avg_dry      = avg_dry |> Decimal.div(100)
        as_fed_sales = as_fed_sales |> Decimal.mult(avg_dry) |> Decimal.add(get_field(changeset, :as_fed_cost, 0))
         
        cond do
          Decimal.lt?(avg_dry, 0) || Decimal.eq?(avg_dry, 0) ->
            put_change(changeset, :as_fed_sales, 0.0)
            |> put_change(:as_fed_sales_100, 0.0)
            |> put_change(:as_fed_cost_100, 0.0)
          get_change(changeset, :avg_dry_100) || get_change(changeset, :as_fed_cost) ->
            changeset
            |> put_change(:as_fed_sales, Decimal.round(as_fed_sales, 2))
            |> put_change(:as_fed_sales_100, Decimal.div(as_fed_sales, avg_dry) |> Decimal.round(2))
            |> put_change(:as_fed_cost_100, Decimal.div(get_field(changeset, :as_fed_cost, 0), avg_dry) |> Decimal.round(2))
          get_change(changeset, :avg_feed_markup) ->
            changeset
            |> put_change(:as_fed_sales, Decimal.round(as_fed_sales, 2))
            |> put_change(:as_fed_sales_100, Decimal.div(as_fed_sales, avg_dry) |> Decimal.round(2))
          true ->
            changeset
        end
      true -> changeset
    end
  end

  # to do make this better.
  defp calc_total_head(changeset) do
    apt = get_assoc(changeset, :assumption_population_totals)

    cond do
      apt && get_field(changeset, :id) ->
        values = Enum.reduce(apt, %{}, fn x, acc -> 
          cond do
            !get_field(x, :is_total) -> 
              Enum.reduce(1..12, %{}, fn month, acc -> 
                Map.put(acc, "month_#{month}" |> String.to_atom, get_field(x, "month_#{month}" |> String.to_atom) + Map.get(acc, "month_#{month}" |> String.to_atom, 0)) 
              end) 
              |> Map.merge(acc, fn _k, v1, v2 -> v1 + v2 end)
            true -> acc
          end
        end)

        total = Enum.find(
          apt, 
          %AssumptionPopulationTotal{} |> AssumptionPopulationTotal.changeset(%{
            is_total: true,
            draft_id: get_field(changeset, :id)
          })
          |> Map.put(:action, :insert),
          fn x -> get_field(x, :is_total) end
        )
        total = Enum.reduce(1..12, total, fn month, acc -> put_change(acc, "month_#{month}" |> String.to_atom, Map.get(values, "month_#{month}" |> String.to_atom, 0)) end)

        apt = cond do
          Enum.any?(apt, fn x -> get_field(x, :is_total) end) ->
            Enum.map(apt, fn x ->
              cond do
                get_field(x, :is_total) -> total
                true -> x
              end
            end)
          true -> apt ++ [total]
        end

        changeset
        |> put_assoc(:assumption_population_totals, apt)
      true -> changeset
    end

  end

  defp calc_head_days(changeset) do
    act = get_assoc(changeset, :assumption_commodity_totals)
    apt = get_assoc(changeset, :assumption_population_totals)

    start_year  = get_field(changeset, :year)
    start_month = 
      get_field(changeset, :company_budget, %{}) 
      |> case do
        nil -> nil
        company_budget -> company_budget |> Map.get(:starting_month)
      end

    cond do
      act && apt && start_month ->
        apt_total = Enum.find(apt, fn x -> get_field(x, :is_total) end)

        cond do
          apt_total ->
            head_days = Enum.find(
              act, 
              %AssumptionCommodityTotal{} |> AssumptionCommodityTotal.changeset(%{
                draft_id: get_field(changeset, :id),
                variable_input_name: "Head Days"
              }),
              fn x -> get_field(x, :variable_input_name) == "Head Days" end
            )
            
            head_days = Enum.reduce(1..12, head_days, fn month, acc ->
              year = start_year + cond do
                start_month + month <= 13 && start_month > 6  -> -1
                start_month + month > 13  && start_month <= 6 -> 1
                true -> 0
              end
              current_month = (start_month + month - 1) |> case do
                x when x > 12 -> x - 12
                x -> x
              end
              dom = Calendar.ISO.days_in_month(year, current_month)

              acc
              |> put_change("month_#{month}" |> String.to_atom, get_field(apt_total, "month_#{month}" |> String.to_atom) * dom)

            end)

            act = Enum.map(act, fn x ->
              cond do
                get_field(x, :variable_input_name) == "Head Days" -> head_days
                true -> x
              end
            end)

            changeset
            |> put_assoc(:assumption_commodity_totals, act)
          true -> changeset
        end
      true -> changeset
    end
  end

  defp calc_tons_fed(changeset) do
    assumption_commodity_totals  = get_assoc(changeset, :assumption_commodity_totals)

    draft_id                     = get_field(changeset, :id)
    assumption_population_totals = get_field(changeset, :assumption_population_totals, [])
    consumption_assumptions      = get_field(changeset, :consumption_assumptions,      [])
    avg_dry                      = get_field(changeset, :avg_dry_100,                  0)

    company_budget = get_field(changeset, :company_budget, %{})
    draft_year     = get_field(changeset, :year)

    cond do 
      company_budget && draft_year && assumption_commodity_totals && draft_id && assumption_population_totals && consumption_assumptions && avg_dry && avg_dry != Decimal.new("0.00") ->
        starting_month = company_budget |> Map.get(:starting_month)
        prev_tons_fed = Enum.find(
          assumption_commodity_totals, 
          %AssumptionCommodityTotal{} |> AssumptionCommodityTotal.changeset(%{
            draft_id:             draft_id, 
            variable_input_name: "Tons Fed"
          }),
          fn x -> get_field(x, :variable_input_name) == "Tons Fed" end
        )

        tons_fed = Enum.reduce(1..12, prev_tons_fed, fn month, acc ->
          draft_month = starting_month - 1 + month |> fn x -> if x > 12, do: x - 12, else: x end.()
          year = if starting_month - 1 + month > 12, do: draft_year + 1, else: draft_year
          assumption_population_totals
          |> Enum.map(fn apt -> 
            consumption_assumptions
            |> Enum.filter(&(&1.animal_type_id == apt.animal_type_id))
            |> Enum.map(fn ca ->
              cond do
                ca.in_weight && ca.out_weight && year && draft_month && month && avg_dry && avg_dry != Decimal.new("0") ->
                    apt
                    |> Map.get("month_#{month}" |> String.to_atom)
                    |> Decimal.mult(Decimal.add(ca.in_weight, ca.out_weight) |> Decimal.div(2))
                    |> Decimal.mult(Calendar.ISO.days_in_month(year, draft_month)) # dom
                    |> Decimal.mult(Decimal.div(ca |> Map.get("month_#{month}" |> String.to_atom), avg_dry))
                    |> Decimal.round(2)
                true -> Decimal.new(0)
              end
            end)
            |> Enum.reduce(Decimal.new(0), fn x, acc -> Decimal.add(x, acc) end)
          end)
          |> Enum.reduce(Decimal.new(0), fn x, acc -> Decimal.add(x, acc) end)
          |> fn x -> put_change(acc, "month_#{month}" |> String.to_atom, x) end.()
        end)
        |> fn x -> put_change(x, :total, Enum.reduce(1..12, Decimal.new(0), fn month, acc -> Decimal.add(get_field(x, "month_#{month}" |> String.to_atom), acc) end)) end.()

        new_assumption_commodity_totals = 
          cond do
            Enum.any?(assumption_commodity_totals, fn x -> get_field(x, :variable_input_name) == "Tons Fed" end) ->
              assumption_commodity_totals
              |> Enum.map(fn x -> if get_field(x, :variable_input_name) == "Tons Fed", do: tons_fed, else: x end)
            true ->
              assumption_commodity_totals ++ [tons_fed]
          end
          |> Enum.reject(&is_nil(&1))

        changeset
        |> put_assoc(:assumption_commodity_totals, new_assumption_commodity_totals)
      true -> changeset
    end
  end
end
