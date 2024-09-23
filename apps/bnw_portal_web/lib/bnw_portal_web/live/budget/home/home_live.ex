defmodule BnwPortalWeb.Budget.Home.HomeLive do
  use BnwPortalWeb, :live_view

  alias BnwPortalWeb.Budget.Home.Modals.{
    ChangeDrafts,
  }

  alias BnwPortalWeb.Budget.Home.Components.{
    DraftItem,
  }

  alias Budget.{
    Admins,
    Companies,
    CompanyAnimalSexes,
    CompanyAnimalTypes,
    CompanyLocations,
    CompanyDraftTypes,
    CompanyVariableInputs,
    Reports,
    Drafts,
    DraftsVariablePlanningLines,
    DraftsFixedPlanningLines,
    DraftsExtraPlanningLines,
    Drafts.Draft,
    Repo,
  }

  @preload [
    :consumption_assumptions, 
    :assumption_population_totals, 
    :assumption_commodity_totals, 
    :misc_incomes,
    :draft_type,
    variable_planning_lines: Drafts.query_variable_planning_lines(),
    fixed_planning_lines:    Drafts.query_fixed_planning_lines(),
    extra_planning_lines:    Drafts.query_extra_planning_lines(),
    monthly_inputs:          Drafts.query_monthly_inputs(),
    company_budget: [budget_accounts: [department_account: [:department, :account]]], 
  ]

  defp fetch_user_permissions(socket) do
    %{current_user: user} = socket.assigns
    %{home_permissions: home_permissions} = Budget.UserRoles.fetch_user_permissions(user.id)

    socket |> assign(:home_permissions, home_permissions) |> assign(:admin, Admins.is_admin(user.id) && user.admin_mode)
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

  def filter_list(companies, :companies, perms, user, admin), do:
    companies
    |> Enum.filter(&check_perm(["view", "lock", "edit"], perms, %{company: &1.id, budget: 0, draft_type: 0, draft: 0}, "drafts", user, admin))
  def filter_list(company_budgets, :company_budgets, perms, user, admin), do:
    company_budgets
    |> Enum.filter(&check_perm(["view", "lock", "edit"], perms, %{company: &1.company_id, budget: &1.id, draft_type: 0, draft: 0}, "drafts", user, admin))
  def filter_list(draft_types, :draft_types, perms, user, admin), do:
    draft_types
    |> Enum.filter(&check_perm(["view", "lock", "edit"], perms, %{company: &1.company_id, draft_type: &1.id, budget: 0, draft: 0}, "drafts", user, admin))

  defp adjust_selected(socket) do
    %{
      selected:         selected,
      home_permissions: home_permissions,
    } = socket.assigns

    company     = check_perm(["view", "lock", "edit"], home_permissions, %{company: selected.company, budget: 0, draft_type: 0, draft: 0}, "drafts", socket.assigns.current_user, socket.assigns.admin)
    budget      = check_perm(["view", "lock", "edit"], home_permissions, %{company: selected.company, budget: selected.budget, draft_type: 0, draft: 0}, "drafts", socket.assigns.current_user, socket.assigns.admin)
    draft_type  = check_perm(["view", "lock", "edit"], home_permissions, %{company: selected.company, budget: selected.budget, draft_type: selected.draft_type, draft: 0}, "drafts", socket.assigns.current_user, socket.assigns.admin)
    draft       = check_perm(["view", "lock", "edit"], home_permissions, %{company: selected.company, budget: selected.budget, draft_type: selected.draft_type, draft: selected.draft}, "drafts", socket.assigns.current_user, socket.assigns.admin)

    selected = 
      selected
      |> Map.put(:company,     (if company,    do: selected.company,    else: 0))
      |> Map.put(:budget,      (if budget,     do: selected.budget,     else: 0))
      |> Map.put(:draft_type,  (if draft_type, do: selected.draft_type, else: 0))
      |> Map.put(:draft,       (if draft,      do: selected.draft,      else: 0))

    socket
    |> assign(selected: selected)
    |> set_default_selected()
  end

  defp fetch_companies(socket) do
    socket
    |> assign(:companies, Companies.list(
      %{
        preload: [company_budgets: Companies.query_budgets(), draft_types: Companies.query_draft_types()]
      })
      |> Enum.reject(&(&1.draft_types == [] or &1.company_budgets == []))
    )
  end

  defp fetch_drafts(socket) do
    %{selected: selected} = socket.assigns
    socket
    |> assign(:drafts, Drafts.list(%{selected: selected, preload: @preload}))
  end

  defp fetch_selected_draft(socket) do
    %{selected: selected, drafts: drafts} = socket.assigns

    draft = drafts |> Enum.find(&(&1.id == selected.draft))
    changeset = draft |> case do
      nil   -> nil
      draft -> Drafts.change(draft)
    end

    socket
    |> assign(:draft,     draft)
    |> assign(:changeset, changeset)
  end

  defp fetch_animal_sexes(socket) do
    %{selected: selected} = socket.assigns
    socket
    |> assign(:animal_sexes, CompanyAnimalSexes.list(%{company_id: selected.company}))
  end

  defp fetch_animal_types(socket) do
    %{selected: selected} = socket.assigns
    socket
    |> assign(:animal_types, CompanyAnimalTypes.list(%{company_id: selected.company}))
  end

  defp fetch_variable_inputs(socket) do
    %{selected: selected} = socket.assigns
    socket
    |> assign(:variable_inputs, CompanyVariableInputs.list(%{company_id: selected.company, active: true}))
  end

  defp fetch_reports(socket) do
    socket
    |> assign(:reports, Reports.list(%{active: true}) |> Enum.map(&(Reports.decorate(&1))))
  end

  defp set_default_selected(socket) do
    %{
      selected:         selected,
      companies:        companies,
      home_permissions: home_permissions,
    } = socket.assigns


    selected = set_default_selected(selected, :company, companies |> filter_list(:companies, home_permissions, socket.assigns.current_user, socket.assigns.admin))
    company = Enum.find(companies, %{company_budgets: [], draft_types: []}, &(&1.id == selected.company))
    selected =
      selected
      |> set_default_selected(:budget,     company.company_budgets |> filter_list(:company_budgets, home_permissions, socket.assigns.current_user, socket.assigns.admin))
      |> set_default_selected(:draft_type, company.draft_types |> filter_list(:draft_types, home_permissions, socket.assigns.current_user, socket.assigns.admin))

    socket
    |> assign(:selected, selected)
  end

  defp set_default_selected(selected, key, []), do: Map.put(selected, key, 0)
  defp set_default_selected(selected, key, list) do
    cond do
      Map.get(selected, key) == 0 -> Map.put(selected, key, Enum.at(list, 0, %{id: 0}).id)
      true -> selected
    end
  end

  defp extract(params, key) do
    params
    |> Enum.reduce([], fn {k, v}, acc -> 
      cond do
        String.starts_with?(k, key) -> [(if String.to_integer(Map.get(v, "id", "-1")) < 0, do: Map.delete(v, "id"), else: v) | acc]
        true -> acc
      end
    end)
    |> fn x -> params |> Enum.reject(fn {k, _v} -> String.starts_with?(k, key) end) |> Map.new() |> Map.put(key, x) end.()
  end

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, :new, _) do
    %{
      companies:   companies,
      modal_stack: modal_stack,
      selected:    selected,
    } = socket.assigns

    company = Enum.find(companies, %{draft_types: []}, &(&1.id == selected.company))
    budget = Enum.find(company.company_budgets, %{draft_types: []}, &(&1.id == selected.budget))

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeDrafts,
      changeset: Drafts.new_changeset(%{draft_type_id: selected.draft_type}),
      opts:      %{
        selected:       selected,
        draft_types:    company |> Map.get(:draft_types),
        starting_month: budget  |> Map.get(:starting_month),
      }
    }))
  end

  defp set_modal(socket, :edit, id) do
    %{
      companies:   companies,
      modal_stack: modal_stack,
      selected:    selected,
    } = socket.assigns

    changeset =
      id
      |> Drafts.get_draft()
      #|> Drafts.preload(%{preload: @preload})
      |> Drafts.change()

    company = Enum.find(companies, %{draft_types: []}, &(&1.id == selected.company))
    budget = Enum.find(company.company_budgets, %{draft_types: []}, &(&1.id == selected.budget))

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:     :new,
      id:        :new,
      module:    ChangeDrafts,
      changeset: changeset,
      opts:      %{
        selected:       selected,
        draft_types:    company |> Map.get(:draft_types),
        starting_month: budget |> Map.get(:starting_month),
      }
    }))
  end

  defp set_modal(socket, :reports, id) when not is_nil(id) do
    %{ 
      modal_stack: modal_stack,
      reports:     reports,
      selected:    selected,
    } = socket.assigns
    socket
    |> assign(:modal_stack, [%Modal{
      modal:  :report,
      id:     :report,
      opts:   %{report: Enum.find(reports, &(&1.id == id)) |> Reports.decorate(selected.draft)},
    } | modal_stack])
  end

  defp set_modal(socket, :reports, _) do
    %{ 
      modal_stack: modal_stack,
      reports:     reports
    } = socket.assigns

    socket
    |> assign(:modal_stack, 
      cond do
        length(reports) == 1 ->
          [%Modal{
            modal:  :report,
            id:     :report,
            opts:   %{report: Enum.at(reports, 0) |> Reports.decorate()},
          } | modal_stack]
        length(reports) > 1 ->
          [ %Modal{
            modal:  :pick_reports,
            id:     :pick_reports,
            module: nil
          } | modal_stack]
        true -> 
          modal_stack
      end)
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Admins.subscribe()
      Companies.subscribe()
      CompanyLocations.subscribe()
      CompanyDraftTypes.subscribe()
      CompanyAnimalSexes.subscribe()
      CompanyAnimalTypes.subscribe()
      CompanyVariableInputs.subscribe()
      Drafts.subscribe()
      DraftsVariablePlanningLines.subscribe()
      DraftsFixedPlanningLines.subscribe()
      DraftsExtraPlanningLines.subscribe()
      Budget.UserRoles.subscribe()
      Budget.Roles.subscribe()
      Budget.HomePermissions.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Budget", "Home")
    |> assign(:anim,        %{loading: nil})
    |> assign(:modal_stack, [])
    |> assign(:session,     %{})
    |> assign(:page,        0)
    |> assign(:per_page,    30)
    |> assign(:companies,   [])
    |> assign(:changeset,   nil)
    |> assign(:selected,    %{
      company:          0,
      budget:           0,
      draft_type:       0,
      draft:            0,
      assumptions:      false,
        consumption:    false,
        income:         false,
        monthly_data:   false,
        misc_income:    false,
      planning:         false,
        departments:    [],
        accounts:       [],
        planning_lines: [],
      monthly_inputs:   false,
      reports:          false,
    })
    |> handle_params(session)
    |> fetch_companies()
    |> fetch_user_permissions()
    |> set_default_selected()
    |> fetch_drafts()
    |> fetch_selected_draft()
    |> fetch_animal_sexes()
    |> fetch_animal_types()
    |> fetch_variable_inputs()
    |> fetch_reports()
    |> res(:ok)
  end

  defp handle_params(socket, %{"company" => company} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | company: company |> String.to_integer()})
    |> assign(:session, Map.put(stored_session, "company", company))
    |> handle_params(session |> Map.delete("company"))
  end
  defp handle_params(socket, %{"budget" => budget} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | budget: budget |> String.to_integer()})
    |> assign(:session, Map.put(stored_session, "budget", budget))
    |> handle_params(session |> Map.delete("budget"))
  end
  defp handle_params(socket, %{"draft_type" => draft_type} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | draft_type: draft_type |> String.to_integer()})
    |> assign(:session, Map.put(stored_session, "draft_type", draft_type))
    |> handle_params(session |> Map.delete("draft_type"))
  end
  defp handle_params(socket, %{"draft" => draft} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | draft: draft |> String.to_integer()})
    |> assign(:session, Map.put(stored_session, "draft", draft))
    |> handle_params(session |> Map.delete("draft"))
  end
  defp handle_params(socket, %{"assumptions" => assumptions} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | assumptions: assumptions == "1"})
    |> assign(:session, Map.put(stored_session, "assumptions", assumptions))
    |> handle_params(session |> Map.delete("assumptions"))
  end
  defp handle_params(socket, %{"consumption" => consumption} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | consumption: consumption == "1"})
    |> assign(:session, Map.put(stored_session, "consumption", consumption))
    |> handle_params(session |> Map.delete("consumption"))
  end
  defp handle_params(socket, %{"income" => income} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | income: income == "1"})
    |> assign(:session, Map.put(stored_session, "income", income))
    |> handle_params(session |> Map.delete("income"))
  end
  defp handle_params(socket, %{"monthly_data" => monthly_data} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | monthly_data: monthly_data == "1"})
    |> assign(:session, Map.put(stored_session, "monthly_data", monthly_data))
    |> handle_params(session |> Map.delete("monthly_data"))
  end
  defp handle_params(socket, %{"misc_income" => misc_income} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | misc_income: misc_income == "1"})
    |> assign(:session, Map.put(stored_session, "misc_income", misc_income))
    |> handle_params(session |> Map.delete("misc_income"))
  end
  defp handle_params(socket, %{"planning" => planning} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | planning: planning == "1"})
    |> assign(:session, Map.put(stored_session, "planning", planning))
    |> handle_params(session |> Map.delete("planning"))
  end
  defp handle_params(socket, %{"departments" => departments} = session) when departments != "" do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | departments: departments |> String.split(",") |> Enum.map(&String.to_integer/1)})
    |> assign(:session, Map.put(stored_session, "departments", departments))
    |> handle_params(session |> Map.delete("departments"))
  end
  defp handle_params(socket, %{"accounts" => accounts} = session) when accounts != "" do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | accounts: accounts |> String.split(",") |> Enum.map(&String.to_integer/1)})
    |> assign(:session, Map.put(stored_session, "accounts", accounts))
    |> handle_params(session |> Map.delete("accounts"))
  end
  defp handle_params(socket, %{"planning_lines" => planning_lines} = session) when planning_lines != "" do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected,
      %{selected |
        planning_lines:
          planning_lines |> String.split(",")
          |> Enum.map(fn x -> 
            String.split(x, ".")
            |> fn [da, p] -> 
              %{department_account_id: String.to_integer(da), planning_line_id: p} 
            end.()
          end)
      }
    )
    |> assign(:session, Map.put(stored_session, "planning_lines", planning_lines))
    |> handle_params(session |> Map.delete("planning_lines"))
  end
  defp handle_params(socket, %{"monthly_inputs" => monthly_inputs} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | monthly_inputs: monthly_inputs == "1"})
    |> assign(:session, Map.put(stored_session, "monthly_inputs", monthly_inputs))
    |> handle_params(session |> Map.delete("monthly_inputs"))
  end
  defp handle_params(socket, %{"reports" => reports} = session) do
    %{session: stored_session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | reports: reports == "1"})
    |> assign(:session, Map.put(stored_session, "reports", reports))
    |> handle_params(session |> Map.delete("reports"))
  end
  defp handle_params(socket, %{"app" => app} = session) do
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "app", app))
    |> handle_params(session |> Map.delete("app"))
  end
  defp handle_params(socket, %{"page" => page} = session) do
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "page", page))
    |> handle_params(session |> Map.delete("page"))
  end
  defp handle_params(socket, %{"admin" => admin} = session) do
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:session, Map.put(stored_session, "admin", admin))
    |> handle_params(session |> Map.delete("admin"))
  end
  defp handle_params(socket, _session), do: socket

  # draft
  @impl true
  def handle_info({[:draft, :created], %Draft{} = draft}, socket) do
    %{selected: selected, drafts: drafts} = socket.assigns
    cond do
      draft.company_budget_id == selected.budget && draft.draft_type_id == selected.draft_type ->
        socket |> assign(:drafts, [draft |> Repo.preload(@preload) | drafts] |> Enum.uniq_by(&(&1.id))) |> res()
      true -> socket
    end
  end
  @impl true
  def handle_info({[:draft, :updated], %Draft{} = draft}, socket) do
    %{drafts: drafts} = socket.assigns
    socket 
    |> assign(:drafts, Enum.map(drafts, &(if &1.id == draft.id, do: draft |> Repo.preload(@preload), else: &1))) 
    |> fetch_selected_draft()
    |> res()
  end
  @impl true
  def handle_info({[:draft, :deleted], del_draft}, socket) do
    %{drafts: drafts, draft: draft} = socket.assigns
    socket 
    |> assign(:drafts, Enum.reject(drafts, &(&1.id == del_draft.id)))
    |> assign(:draft, (if draft.id == del_draft.id, do: nil, else: draft))
    |> res()
  end

  # draft edit
  @impl true
  def handle_info({[:draft, :created], draft}, socket) do
    %{selected: selected, drafts: drafts} = socket.assigns
    cond do
      draft.company_budget_id == selected.budget && draft.draft_type_id == selected.draft_type ->
        socket |> assign(:drafts, [draft.id |> Drafts.get() |> Repo.preload(@preload) | drafts]) |> res()
      true -> socket
    end
  end
  @impl true
  def handle_info({[:draft, :updated], draft}, socket) do
    %{drafts: drafts} = socket.assigns
    socket 
    |> assign(:drafts, Enum.map(drafts, &(if &1.id == draft.id, do: draft.id |> Drafts.get() |> Repo.preload(@preload), else: &1))) 
    |> fetch_selected_draft()
    |> res()
  end

  # variable_planning_line
  @impl true
  def handle_info({[:draft_variable_planning_line, :created], variable_planning_line}, socket) do
    %{drafts: drafts} = socket.assigns

    drafts = drafts |> Enum.map(fn draft ->
      cond do
        draft.id == variable_planning_line.draft_id ->
          vpl = draft.variable_planning_lines ++ [variable_planning_line]
          Map.put(draft, :variable_planning_lines, vpl)
        true -> draft
      end
    end)

    socket 
    |> assign(:drafts, drafts)
    |> fetch_selected_draft()
    |> res()
  end
  @impl true
  def handle_info({[:draft_variable_planning_line, :deleted], variable_planning_line}, socket) do
    %{drafts: drafts} = socket.assigns
    drafts = drafts |> Enum.map(fn draft ->
      cond do
        draft.id == variable_planning_line.draft_id ->
          vpl = draft.variable_planning_lines |> Enum.reject(&(&1.id == variable_planning_line.id))
          Map.put(draft, :variable_planning_lines, vpl)
        true -> draft
      end
    end)
    socket
    |> assign(:drafts, drafts)
    |> fetch_selected_draft()
    |> res()
  end

  # fixed_planning_line
  @impl true
  def handle_info({[:draft_fixed_planning_line, :created], fixed_planning_line}, socket) do
    %{drafts: drafts} = socket.assigns

    drafts = drafts |> Enum.map(fn draft ->
      cond do
        draft.id == fixed_planning_line.draft_id ->
          fpl = draft.fixed_planning_lines ++ [fixed_planning_line]
          Map.put(draft, :fixed_planning_lines, fpl)
        true -> draft
      end
    end)

    socket 
    |> assign(:drafts, drafts)
    |> fetch_selected_draft()
    |> res()
  end
  @impl true
  def handle_info({[:draft_fixed_planning_line, :deleted], fixed_planning_line}, socket) do
    %{drafts: drafts} = socket.assigns
    drafts = drafts |> Enum.map(fn draft ->
      cond do
        draft.id == fixed_planning_line.draft_id ->
          fpl = draft.fixed_planning_lines |> Enum.reject(&(&1.id == fixed_planning_line.id))
          Map.put(draft, :fixed_planning_lines, fpl)
        true -> draft
      end
    end)
    socket
    |> assign(:drafts, drafts)
    |> fetch_selected_draft()
    |> res()
  end

  # extra_planning_line
  @impl true
  def handle_info({[:draft_extra_planning_line, :created], extra_planning_line}, socket) do
    %{drafts: drafts} = socket.assigns

    drafts = drafts |> Enum.map(fn draft ->
      cond do
        draft.id == extra_planning_line.draft_id ->
          epl = draft.extra_planning_lines ++ [extra_planning_line]
          Map.put(draft, :extra_planning_lines, epl)
        true -> draft
      end
    end)

    socket 
    |> assign(:drafts, drafts)
    |> fetch_selected_draft()
    |> res()
  end
  @impl true
  def handle_info({[:draft_extra_planning_line, :deleted], extra_planning_line}, socket) do
    %{drafts: drafts} = socket.assigns
    drafts = drafts |> Enum.map(fn draft ->
      cond do
        draft.id == extra_planning_line.draft_id ->
          epl = draft.extra_planning_lines |> Enum.reject(&(&1.id == extra_planning_line.id))
          Map.put(draft, :extra_planning_lines, epl)
        true -> draft
      end
    end)
    socket
    |> assign(:drafts, drafts)
    |> fetch_selected_draft()
    |> res()
  end

  # company
  @impl true
  def handle_info({[:company, :created], company}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, [company |> Repo.preload([:locations, :draft_types]) | companies]) |> res()
  end
  @impl true
  def handle_info({[:company, :updated], company}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, Enum.map(companies, &(if &1.id == company.id, do: company |> Repo.preload([:locations, :draft_types]), else: &1))) |> res()
  end
  @impl true
  def handle_info({[:company, :deleted], company}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, Enum.reject(companies, &(&1.id == company.id))) |> res()
  end

  # location
  @impl true
  def handle_info({[:location, :created], location}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, Enum.map(companies, &(if &1.id == location.company_id, do: %{&1 | locations: [location | &1.locations]}, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:location, :updated], location}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, Enum.map(companies, fn c -> if c.id == location.company_id, do: %{c | locations: Enum.map(c.locations, fn l -> if l.id == location.id, do: location, else: l end)}, else: c end)) |> res()
  end
  @impl true
  def handle_info({[:location, :deleted], location}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, Enum.map(companies, fn c -> if c.id == location.company_id, do: %{c | locations: Enum.reject(c.locations, fn l -> l.id == location.id end)}, else: c end)) |> res()
  end

  # location
  @impl true
  def handle_info({[:draft_type, :created], draft_type}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, Enum.map(companies, fn c -> if c.id == draft_type.company_id, do: %{c | draft_types: [draft_type | c.draft_types] |> Enum.sort_by(&(&1.order_number))}, else: c end)) |> res()
  end
  @impl true
  def handle_info({[:draft_type, :updated], draft_type}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, Enum.map(companies, fn c -> if c.id == draft_type.company_id, do: %{c | draft_types: Enum.map(c.draft_types, fn dt -> if dt.id == draft_type.id, do: draft_type, else: dt end) |> Enum.sort_by(&(&1.order_number))}, else: c end)) |> res()
  end
  @impl true
  def handle_info({[:draft_type, :deleted], draft_type}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, Enum.map(companies, fn c -> if c.id == draft_type.company_id, do: %{c | draft_types: Enum.reject(c.draft_types, fn dt -> dt.id == draft_type.id end)}, else: c end)) |> res()
  end

  # permission changed
  @impl true
  def handle_info({[:budget, _, _], _}, socket), do: socket |> fetch_user_permissions() |> adjust_selected() |> fetch_drafts() |> res()


  @impl true
  def handle_info(:cancel, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_event("add_new", _, socket), do: set_modal(socket, :new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: set_modal(socket, :edit, id |> String.to_integer()) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    %{drafts: drafts} = socket.assigns

    Enum.find(drafts, &(&1.id == id |> String.to_integer())) |> Drafts.delete()
    socket |> res()
  end

  @impl true
  def handle_event("lock", %{"id" => id}, socket) do
    %{drafts: drafts} = socket.assigns

    Enum.find(drafts, &(&1.id == id |> String.to_integer())) |> Drafts.toggle_lock()
    socket |> res()
  end

  @impl true
  def handle_event("select_company", %{"id" => id}, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:session,  session |> Map.put("company", id) |> Map.put("budget", 0) |> Map.put("draft_type", 0))
    |> assign(:selected, selected |> Map.put(:company, id |> String.to_integer()) |> Map.put(:budget, 0) |> Map.put(:draft_type, 0))
    |> assign(:drafts, [])
    |> assign(:draft,  nil)
    |> set_default_selected()
    |> fetch_drafts()
    |> fetch_animal_sexes()
    |> fetch_animal_types()
    |> fetch_variable_inputs()
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_budget", %{"id" => id}, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:session, Map.put(session, "budget", id))
    |> assign(:selected, %{selected | budget: id |> String.to_integer()})
    |> assign(:drafts, [])
    |> assign(:draft,  nil)
    |> fetch_drafts()
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_draft_type", %{"id" => id}, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:session, Map.put(session, "draft_type", id))
    |> assign(:selected, %{selected | draft_type: id |> String.to_integer()})
    |> assign(:drafts, [])
    |> assign(:draft,  nil)
    |> fetch_drafts()
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_draft", %{"id" => id}, socket) do
    %{session: session, selected: selected} = socket.assigns
    id = id |> String.to_integer()
    draft = if id == selected.draft, do: 0, else: id
    socket
    |> assign(:selected, %{selected | draft: draft})
    |> assign(:session, Map.put(session, "draft", draft))
    |> fetch_selected_draft()
    |> assign_async(:anim, fn -> 
      :timer.sleep(1000)
      {:ok, %{anim: false}} 
    end)
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_assumptions", _, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | assumptions: !selected.assumptions})
    |> assign(:session, Map.put(session, "assumptions", (if !selected.assumptions, do: 1, else: 0)))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_consumption", _, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | consumption: !selected.consumption})
    |> assign(:session, Map.put(session, "consumption", (if !selected.consumption, do: 1, else: 0)))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_income", _, socket) do
    %{session: session, selected: selected} = socket.assigns

    socket
    |> assign(:selected, %{selected | income: !selected.income})
    |> assign(:session, Map.put(session, "income", (if !selected.income, do: 1, else: 0)))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_monthly_data", _, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | monthly_data: !selected.monthly_data})
    |> assign(:session, Map.put(session, "monthly_data", (if !selected.monthly_data, do: 1, else: 0)))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_misc_income", _, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | misc_income: !selected.misc_income})
    |> assign(:session, Map.put(session, "misc_income", (if !selected.misc_income, do: 1, else: 0)))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_planning", _, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | planning: !selected.planning})
    |> assign(:session, Map.put(session, "planning", (if !selected.planning, do: 1, else: 0)))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_department", %{"id" => id}, socket) do
    %{session: session, selected: selected} = socket.assigns
    id = id |> String.to_integer()
    departments = cond do
      Enum.any?(selected.departments, &(&1 == id)) -> Enum.reject(selected.departments, &(&1 == id))
      true -> [id | selected.departments]
    end
    socket
    |> assign(:selected, %{selected | departments: departments})
    |> assign(:session, Map.put(session, "departments", Enum.join(departments, ",")))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_account", %{"department_account_id" => id}, socket) do
    %{session: session, selected: selected} = socket.assigns
    id = id |> String.to_integer()
    accounts = cond do
      Enum.any?(selected.accounts, &(&1 == id)) -> Enum.reject(selected.accounts, &(&1 == id))
      true -> [id | selected.accounts]
    end
    socket
    |> assign(:selected, %{selected | accounts: accounts})
    |> assign(:session, Map.put(session, "accounts", Enum.join(accounts, ",")))
    |> push_changes(:patch)
    |> res()
  end

  @impl true 
  def handle_event("select_planning_line", %{"department_account_id" => da_id, "planning_line_id" => pl_id}, socket) do
    %{session: session, selected: selected} = socket.assigns
    da_id = da_id |> String.to_integer()
    pl_id = pl_id

    planning_lines = cond do
      Enum.any?(selected.planning_lines, &(&1.planning_line_id == pl_id && &1.department_account_id == da_id)) -> 
        Enum.reject(selected.planning_lines, &(&1.planning_line_id == pl_id && &1.department_account_id == da_id))
      true -> [%{planning_line_id: pl_id, department_account_id: da_id} | selected.planning_lines]
    end
    planning_lines_string = Enum.reduce(planning_lines, "", fn %{planning_line_id: pl_id, department_account_id: da_id}, acc -> acc <> "#{da_id}.#{pl_id}," end) |> String.trim_trailing(",")

    socket
    |> assign(:selected, %{selected | planning_lines: planning_lines})
    |> assign(:session, Map.put(session, "planning_lines", planning_lines_string))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_monthly_inputs", _, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | monthly_inputs: !selected.monthly_inputs})
    |> assign(:session, Map.put(session, "monthly_inputs", (if !selected.monthly_inputs, do: 1, else: 0)))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("select_reports", _, socket) do
    %{session: session, selected: selected} = socket.assigns
    socket
    |> assign(:selected, %{selected | reports: !selected.reports})
    |> assign(:session, Map.put(session, "reports", (if !selected.reports, do: 1, else: 0)))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event("reports", %{"id" => id}, socket), do: socket |> set_modal(:reports, id |> String.to_integer) |> res()

  @impl true
  def handle_event("validate", params, socket) do
    %{changeset: changeset} = socket.assigns

    params = 
      params 
      |> Map.get("draft", %{})
      |> extract("consumption_assumptions")
      |> extract("assumption_population_totals")
      |> extract("assumption_commodity_totals")
      |> extract("misc_incomes")
      |> extract("variable_planning_lines")
      |> extract("fixed_planning_lines")
      |> extract("extra_planning_lines")
      |> extract("monthly_inputs")

    changeset =
      changeset.data
      |> Drafts.change(params)
      |> Map.put(:action, :insert)
    
    socket 
    |> assign(:changeset, changeset)
    |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{changeset: changeset} = socket.assigns

    params = 
      params 
      |> Map.get("draft", %{})
      |> extract("consumption_assumptions")
      |> extract("assumption_population_totals")
      |> extract("assumption_commodity_totals")
      |> extract("misc_incomes")
      |> extract("variable_planning_lines")
      |> extract("fixed_planning_lines")
      |> extract("extra_planning_lines")
      |> extract("monthly_inputs")

    changeset =
      changeset.data
      |> Drafts.change(params)
      |> Map.put(:action, :insert)

    cond do
      changeset.valid? ->
        changeset.data |> Drafts.create_or_update(params)
        |> case do
          {:ok, _data}        -> socket
          {:error, changeset} -> socket |> assign(:changeset, changeset)
        end
      true -> socket
    end
    |> res()
  end

  @impl true
  def handle_event("new_vpl", %{"department_account_id" => da_id}, socket) do
    %{changeset: changeset} = socket.assigns
    
    DraftsVariablePlanningLines.new()
    |> DraftsVariablePlanningLines.create_or_update(%{draft_id: changeset.data.id, department_account_id: da_id})

    socket |> res()
  end

  @impl true
  def handle_event("delete_vpl", %{"id" => id}, socket) do
    DraftsVariablePlanningLines.delete(id |> String.to_integer())
    socket |> res()
  end

  @impl true
  def handle_event("new_fpl", %{"department_account_id" => da_id}, socket) do
    %{changeset: changeset} = socket.assigns

    DraftsFixedPlanningLines.new()
    |> DraftsFixedPlanningLines.create_or_update(%{draft_id: changeset.data.id, department_account_id: da_id})

    socket |> res()
  end

  @impl true
  def handle_event("delete_fpl", %{"id" => id}, socket) do
    DraftsFixedPlanningLines.delete(id |> String.to_integer())
    socket |> res()
  end

  @impl true
  def handle_event("new_epl", %{"department_account_id" => da_id}, socket) do
    %{changeset: changeset} = socket.assigns

    DraftsExtraPlanningLines.new()
    |> DraftsExtraPlanningLines.create_or_update(%{draft_id: changeset.data.id, department_account_id: da_id})

    socket |> res()
  end

  @impl true
  def handle_event("delete_epl", %{"id" => id}, socket) do
    DraftsExtraPlanningLines.delete(id |> String.to_integer())
    socket |> res()
  end

  @impl true
  def handle_event("cancel_edit", _, socket), do: socket |> fetch_selected_draft() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
