defmodule BnwPortalWeb.Budget.Companies.CompaniesLive do
  use BnwPortalWeb, :live_view


  alias BnwPortalWeb.Budget.Companies.Modals.{
    ChangeCompanies,
    ChangeLocations,
    ChangeVariableInputs,
    ChangeReportingInputs,
    ChangeMiscInputs,
    ChangeAccounts,
    ChangeDepartments,
    ChangeDepartmentAccounts,
    ChangeBudgets,
    ChangeBudgetAccounts,
    ChangeDraftTypes,
    ChangeAnimalSexes,
    ChangeAnimalTypes,
    ChangeRoles,
    ChangeHomePermissions,
    ChangeCompanyPermissions,
    ChangeUserRoles,
  }
  alias Budget.{
    Admins,
    Companies,
    CompanyPermissions,
    UserRoles,
  }

  @modals %{
    :locations           => ChangeLocations,
    :variable_inputs     => ChangeVariableInputs,
    :reporting_inputs    => ChangeReportingInputs,
    :misc_inputs         => ChangeMiscInputs,
    :accounts            => ChangeAccounts,
    :departments         => ChangeDepartments,
    :budgets             => ChangeBudgets,
    :draft_types         => ChangeDraftTypes,
    :animal_sexes        => ChangeAnimalSexes,
    :animal_types        => ChangeAnimalTypes,
    :roles               => ChangeRoles,
    :user_roles          => ChangeUserRoles,
  }

  defp fetch_user_permissions(socket) do
    %{current_user: user} = socket.assigns
    %{company_permissions: company_permissions} = UserRoles.fetch_user_permissions(user.id)

    socket |> assign(:company_permissions, company_permissions) |> assign(:admin, Admins.is_admin(user.id) && user.admin_mode)
  end

  def check_perm(_perms, _company_id, _section, user, admin) when (user.dev_admin and user.admin_mode) or admin do
    ["admin"]
  end
  def check_perm(perms, company_id, section, _user, _admin) do
    perms
    |> Enum.filter(&(&1.company_id == company_id && &1.section == section))
    |> Enum.map(&(&1.permission))
    |> Enum.uniq()
  end

  defp fetch_companies(socket) do
    %{
      page:         page,
      per_page:     per_page,
      companies:    companies,
      search_stack: search_stack,
      sort_stack:   sort_stack,
    } = socket.assigns
    socket |> assign(:companies, companies ++ Companies.list(
      %{
        page:         page,
        per_page:     per_page,
        search_stack: search_stack,
        sort_stack:   sort_stack,
      }
    ) |> Enum.uniq_by(&(&1.id)))
  end

  defp fetch_sections(socket), do: socket |> assign(:sections, CompanyPermissions.list_sections())

  defp reload_items(socket), do: socket |> assign(:companies, []) |> fetch_companies()

  defp set_modal(socket, type \\ nil, id \\ nil)
  defp set_modal(socket, type, id) when is_map_key(@modals, type) do
    %{
      companies:    companies,
      modal_stack:  modal_stack,
      current_user: user,
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:        type,
      module:       Map.get(@modals, type),
      live:         true,
      user:         user,
      id:           :id,
      opts:         %{
        company_id:   id,
        company_name: Enum.find(companies, &(&1.id == id)).name,
        user_id:      user.id
      }
    }))
  end
  defp set_modal(socket, :new, _) do
    %{
      current_user: user,
      modal_stack:  modal_stack,
    } = socket.assigns
    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:     :new,
      user:      user,
      id:        :new,
      module:    ChangeCompanies,
      changeset: Companies.new_changeset()
    }))
  end

  defp set_modal(socket, :edit, id) do
    %{
      current_user: user,
      modal_stack:  modal_stack,
    } = socket.assigns
    changeset =
      id
      |> Companies.get()
      |> Companies.change()

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:     :edit,
      user:      user,
      id:        :id,
      module:    ChangeCompanies,
      changeset: changeset,
    }))
  end

  defp set_modal(socket, :department_accounts, {department_id, company_id, department_name}) do
    %{
      companies:   companies,
      current_user: user,
      modal_stack: modal_stack,
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:           :department_accounts,
      module:          ChangeDepartmentAccounts,
      live:            true,
      user:            user,
      id:              :id,
      opts:            %{
        department_id:   department_id,
        department_name: department_name,
        company_id:      company_id,
        company_name:    Enum.find(companies, &(&1.id == company_id)).name,
      }
    }))
  end

  defp set_modal(socket, :budget_accounts, {budget_id, company_id, budget_name}) do
    %{
      companies:    companies,
      current_user: user,
      modal_stack:  modal_stack,
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:        :budget_departments,
      module:       ChangeBudgetAccounts,
      live:         true,
      user:         user,
      id:           :id,
      opts:         %{
        budget_id:    budget_id,
        budget_name:  budget_name,
        company_id:   company_id,
        company_name: Enum.find(companies, &(&1.id == company_id)).name,
        user_id:      user.id
      }
    }))
  end

  defp set_modal(socket, :permissions_home, {role_id, company_id, role_name}) do
    %{
      companies:    companies,
      current_user: user,
      modal_stack:  modal_stack,
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:        :permission_home,
      module:       ChangeHomePermissions,
      live:         true,
      user:         user,
      id:           :id,
      opts:         %{
        role_id:      role_id,
        role_name:    role_name,
        company_id:   company_id,
        company_name: Enum.find(companies, &(&1.id == company_id)).name,
        user_id:      user.id
      }
    }))
  end

  defp set_modal(socket, :permissions_company, {role_id, company_id, role_name}) do
    %{
      companies:    companies,
      current_user: user,
      modal_stack:  modal_stack,
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:        :permission_company,
      module:       ChangeCompanyPermissions,
      live:         true,
      user:         user,
      id:           :id,
      opts:         %{
        role_id:      role_id,
        role_name:    role_name,
        company_id:   company_id,
        company_name: Enum.find(companies, &(&1.id == company_id)).name,
        user_id:      user.id
      }
    }))
  end

  defp set_modal(socket, :roles_user_roles, {role_id, company_id, role_name}) do
    %{
      companies:    companies,
      current_user: user,
      modal_stack:  modal_stack,
    } = socket.assigns

    socket
    |> assign(:modal_stack, stack_push(modal_stack, %Modal{
      modal:        :roles_user_roles,
      module:       ChangeUserRoles,
      live:         true,
      user:         user,
      id:           :id,
      opts:         %{
        role_id:      role_id,
        role_name:    role_name,
        company_id:   company_id,
        company_name: Enum.find(companies, &(&1.id == company_id)).name,
        user_id:      user.id
      }
    }))
  end
  defp set_modal(socket, _, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  @impl true
  def mount(_params, session, socket) do
    if connected?(socket) do
      Admins.subscribe()
      Companies.subscribe()
      Budget.UserRoles.subscribe()
      Budget.Roles.subscribe()
      Budget.CompanyPermissions.subscribe()
    end

    socket
    |> bnw_verify_user_token(session, "Companies")
    |> assign(:page,             0)
    |> assign(:per_page,         30)
    |> assign(:selected_company, 0)
    |> assign(:companies,        [])
    |> assign(:modal_stack,      [])
    |> assign(:search_map,       %{}) # search map is for the search form
    |> assign(:search_stack,     [])  # search stack is the data for all the search fields
    |> assign(:sort_stack,       [])  # sort stack is the data for all the sort fields
    |> assign(:session,          %{}) # session is kept so that the session can be updated
    |> handle_params(session)         # here session is the second argument to mount
    |> fetch_sections()
    |> fetch_user_permissions()
    |> fetch_companies()
    |> set_modal()
    |> res(:ok)
  end

  defp handle_params(socket, %{"selected_company" => id} = session) do
    %{session: stored_session} = socket.assigns
    socket
    |> assign(:selected_company, id |> String.to_integer())
    |> assign(:session, Map.put(stored_session, "selected_company", id))
    |> handle_params(session |> Map.delete("selected_company"))
  end

  # note that handle_params is not the normal callback function, so this can be changed as needed
  defp handle_params(socket, %{"search" => _search} = session) do
    socket
    |> search_handle_params(session)
    |> handle_params(session |> Map.delete("search"))
  end
  defp handle_params(socket, %{"sort" => _sort} = session) do
    socket
    |> sort_handle_params(session)
    |> handle_params(session |> Map.delete("sort"))
  end

  # these are required to keep on the app, page and admin
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

  @impl true
  def handle_info({[:company, :created], company}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, [company | companies]) |> res()
  end

  @impl true
  def handle_info({[:company, :updated], company}, socket) do
    %{companies: companies} = socket.assigns
    socket |> assign(:companies, Enum.map(companies, fn c -> if c.id == company.id, do: company, else: c end)) |> res()
  end

  @impl true
  def handle_info({[:company, :deleted], company}, socket) do
    %{companies: companies} = socket.assigns
    socket
    |> assign(:companies, Enum.reject(companies, fn c -> c.id == company.id end))
    |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_info({:department_accounts, id}, socket), do: set_modal(socket, :department_accounts, id) |> res()
  @impl true
  def handle_info({:budget_accounts,     id}, socket), do: set_modal(socket, :budget_accounts,     id) |> res()
  @impl true
  def handle_info({:permissions_home,    id}, socket), do: set_modal(socket, :permissions_home,    id) |> res()
  @impl true
  def handle_info({:permissions_company, id}, socket), do: set_modal(socket, :permissions_company, id) |> res()
  @impl true
  def handle_info({:roles_user_roles,    id}, socket), do: set_modal(socket, :roles_user_roles,    id) |> res()

  # permission changed
  @impl true
  def handle_info({[:budget, _, _], _}, socket), do: socket |> fetch_user_permissions() |> res()

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("add_new", _, socket), do: set_modal(socket, :new) |> res()

  @impl true
  def handle_event("edit", %{"id" => id}, socket), do: set_modal(socket, :edit, id |> String.to_integer()) |> res()

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id |> String.to_integer() |> Companies.delete()
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: set_modal(socket) |> res()

  @impl true
  def handle_event("load_more", _, socket) do
    %{page: page} = socket.assigns

    socket
    |> assign(:page, page + 1)
    |> fetch_companies()
    |> res()
  end

  @impl true
  def handle_event("show", %{"id" => id}, socket) do
    %{session: session} = socket.assigns
    id = String.to_integer(id)
    selected_company = cond do
      id == socket.assigns.selected_company -> 0
      true -> id
    end
    socket
    |> assign(:selected_company, selected_company)
    |> assign(:session, Map.put(session, "selected_company", selected_company))
    |> push_changes(:patch)
    |> res()
  end

  @impl true
  def handle_event(event, %{"id" => id}, socket) when event in [
    "locations",   "variable_inputs", "reporting_inputs", "misc_inputs",
    "accounts",    "departments",     "budgets",
    "draft_types", "animal_sexes",    "animal_types",
    "roles",       "user_roles",
  ] do
    socket |> set_modal(String.to_atom(event), id |> String.to_integer()) |> res()
  end

  @impl true
  def handle_event("sort", params, socket), do: socket |> sort(params) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", %{"field" => field}, socket), do: socket |> search_reset_filter(field) |> reload_items() |> res()
  @impl true
  def handle_event("reset_filters", _, socket), do: socket |> search_reset_filter() |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"search" => _} = params, socket), do: socket |> search(params) |> reload_items() |> res()
  @impl true
  def handle_event("search", %{"field" => _} = params, socket), do: search(socket, params) |> res()
  @impl true
  def handle_event("hide_filter", _, socket), do: socket |> search_hide_filter() |> res()

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end
