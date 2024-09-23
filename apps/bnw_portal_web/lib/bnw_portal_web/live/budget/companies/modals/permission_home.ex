defmodule BnwPortalWeb.Budget.Companies.Modals.ChangeHomePermissions do
  use BnwPortalWeb, :live_view

  alias Budget.{
    Admins,
    CompanyLocations,
    CompanyBudgets,
    CompanyDraftTypes,
    Drafts,
    UserRoles,
    Roles,
    CompanyPermissions,
  }

  @module  Budget.HomePermissions
  @key     "permission_homes"
  @section "roles"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <%= if @view do %>
        <.bnw_modal id="permission_home_modal" width="w-2/3">
          <.bnw_modal_header><%= @modal.opts.company_name %> - <%= @modal.opts.role_name %> - Home Permissions</.bnw_modal_header>
          <.bnw_modal_body>

            <.bnw_expand name="Company" click="select_company" expanded={Map.get(@expanded, :company)}>
              <.gen_perms 
                edit={@edit}
                sections={@sections} 
                perms={@perms} 
                permissions={@permissions} 
              />
            </.bnw_expand>

            <!--
            <.bnw_expand name="Locations" click="select_location" expanded={Map.get(@expanded, :location)}>
              <%# for location <- @locations do %>
                <.bnw_expand name={location.name} click="select_location" click_id={location.id} expanded={Enum.any?(@expanded.locations, &(&1 == location.id))}>
                  <.gen_perms 
                    edit={@edit}
                    location_id={location.id}
                    sections={@sections} 
                    perms={@perms} 
                    permissions={@permissions} 
                  />
                </.bnw_expand>
              <%# end %>
            </.bnw_expand>
            -->

            <.bnw_expand name="Company Budgets" click="select_company_budget" expanded={Map.get(@expanded, :company_budget)}>
              <%= for company_budget <- @company_budgets do %>
                <.bnw_expand name={company_budget.name} click="select_company_budget" click_id={company_budget.id} expanded={Enum.any?(@expanded.company_budgets, &(&1 == company_budget.id))}>
                  <.gen_perms 
                    edit={@edit}
                    company_budget_id={company_budget.id}
                    sections={@sections} 
                    perms={@perms} 
                    permissions={@permissions} 
                  />
                </.bnw_expand>
              <% end %>
            </.bnw_expand>

            <.bnw_expand name="Draft Types" click="select_draft_type" expanded={Map.get(@expanded, :draft_type)}>
              <%= for draft_type <- @draft_types do %>
                <.bnw_expand name={draft_type.name} click="select_draft_type" click_id={draft_type.id} expanded={Enum.any?(@expanded.draft_types, &(&1 == draft_type.id))}>
                  <.gen_perms 
                    edit={@edit}
                    draft_type_id={draft_type.id}
                    sections={@sections} 
                    perms={@perms} 
                    permissions={@permissions} 
                  />
                </.bnw_expand>
              <% end %>
            </.bnw_expand>

            <.bnw_expand name="Drafts" click="select_draft" expanded={Map.get(@expanded, :draft)}>
              <%= for draft <- @drafts do %>
                <.bnw_expand name={draft.name} click="select_draft" click_id={draft.id} expanded={Enum.any?(@expanded.drafts, &(&1 == draft.id))}>
                  <.gen_perms 
                    edit={@edit}
                    draft_id={draft.id}
                    sections={@sections} 
                    perms={@perms} 
                    permissions={@permissions} 
                  />
                </.bnw_expand>
              <% end %>
            </.bnw_expand>
            
          </.bnw_modal_body>
          <.bnw_modal_footer><.bnw_button_done id="a_different_done"/></.bnw_modal_footer>
        </.bnw_modal>
      <% end %>
    </div>
    """
  end

  attr :edit,              :boolean, default:  false
  attr :location_id,       :integer, default:  nil
  attr :company_budget_id, :integer, default:  nil
  attr :draft_type_id,     :integer, default:  nil
  attr :draft_id,          :integer, default:  nil
  attr :sections,          :list,    required: true
  attr :perms,             :list,    required: true
  attr :permissions,       :list,    required: true
  def gen_perms(assigns) do
    ~H"""
      <div class="w-[97%] px-8 mx-8">
        <.bnw_table height="60vh" id={"permission_company_table_#{@location_id}_#{@company_budget_id}_#{@draft_type_id}_#{@draft_id}"} load_more={false}>
          <:header>
            <th class="p-2 w-1/3">Page</th>
            <%= for %{label: label} <- @perms do %>
              <th class="p-2"><%= label %></th>
            <% end %>
          </:header>

          <%= for %{section: section, label: label, perms: perms} <- @sections do %>
            <% 
              perm = Enum.find(@permissions, &(
                &1.section == section
                && ((is_nil(&1.location_id)       && is_nil(@location_id)      ) || &1.location_id       == @location_id)
                && ((is_nil(&1.company_budget_id) && is_nil(@company_budget_id)) || &1.company_budget_id == @company_budget_id)
                && ((is_nil(&1.draft_type_id)     && is_nil(@draft_type_id)    ) || &1.draft_type_id     == @draft_type_id)
                && ((is_nil(&1.draft_id)          && is_nil(@draft_id)         ) || &1.draft_id          == @draft_id)
              ))
            %>
            <tr>
              <td><%= label %></td>
              <%= for {%{permission: permission}, i} <- @perms |> Enum.with_index() do %>
                <td>
                  <%= if Enum.any?(perms, &(&1 == permission)) do %>
                    <% active = perm && perm.permission in (@perms |> Enum.take((length(@perms) - i) * -1) |> Enum.map(&(&1.permission))) %>
                    <.bnw_button_toggle_active 
                      edit={@edit}
                      phx-value-location_id={@location_id}
                      phx-value-company_budget_id={@company_budget_id}
                      phx-value-draft_type_id={@draft_type_id}
                      phx-value-draft_id={@draft_id}
                      phx-value-section={section} 
                      phx-value-permission={permission} 
                      active={active} 
                    />
                  <% end %>
                </td>
              <% end %>
            </tr>
          <% end %>
        </.bnw_table>
      </div>
    """
  end

  defp fetch_user_permissions(socket) do
    %{
      modal:      %{user: user},
      company_id: company_id
    } = socket.assigns
    cond do 
      (user.dev_admin && user.admin_mode) || Admins.is_admin(user.id) -> socket |> assign(:edit, true) |> assign(:view, true)
      true ->
        %{company_permissions: company_permissions} = UserRoles.fetch_user_permissions(user.id)

        edit = Enum.any?(company_permissions, &(&1.company_id == company_id && &1.section == @section && &1.permission in ["admin", "edit"]))
        view = Enum.any?(company_permissions, &(&1.company_id == company_id && &1.section == @section))
        socket |> assign(:edit, edit) |> assign(:view, view)
    end
  end

  defp save(socket) do
    %{changeset: changeset} = socket.assigns
    cond do
      changeset.valid? ->
        changeset.data |> @module.create_or_update(changeset.changes)
        |> case do
          {:ok, _} -> socket |> assign(:changeset, @module.new_changeset()) |> assign(:new, true)
          {:error, changeset} -> socket |> assign(:changeset, changeset)
        end
      true -> socket
    end
  end

  defp cancel(socket) do
    %{parent: parent} = socket.assigns
    send(parent, :cancel)
    socket
  end

  defp fetch_items(socket) do
    %{role_id: role_id} = socket.assigns
    socket |> assign(:permissions, @module.list(%{role_id: role_id}))
  end
  defp fetch_locations(socket) do
    %{company_id: company_id} = socket.assigns
    socket |> assign(:locations, CompanyLocations.list(%{company_id: company_id}))
  end
  defp fetch_company_budgets(socket) do
    %{company_id: company_id} = socket.assigns
    socket |> assign(:company_budgets, CompanyBudgets.list(%{company_id: company_id}))
  end
  defp fetch_draft_types(socket) do
    %{company_id: company_id} = socket.assigns
    socket |> assign(:draft_types, CompanyDraftTypes.list(%{company_id: company_id}))
  end
  defp fetch_drafts(socket) do
    %{company_id: company_id} = socket.assigns
    socket |> assign(:drafts, Drafts.list(%{company_id: company_id}))
  end

  @impl true
  def mount(_params, %{"modal" => modal, "parent" => parent}, socket) do
    if connected?(socket) do
      @module.subscribe()
      Admins.subscribe()
      UserRoles.subscribe()
      Roles.subscribe()
      CompanyPermissions.subscribe()
    end

    socket
    |> assign(:modal,           modal)
    |> assign(:parent,          parent)
    |> assign(:role_id,         modal.opts.role_id)
    |> assign(:company_id,      modal.opts.company_id)
    |> assign(:expanded, %{
      company:         true,
      location:        false,
      locations:       [],
      company_budget:  false,
      company_budgets: [],
      draft_type:      false,
      draft_types:     [],
      draft:           false,
      drafts:          [],
    })
    |> assign(:sections, [
      %{section: "assumptions",    label: "Assumptions",    perms: ["view", "edit"]},
      %{section: "drafts",         label: "Drafts",         perms: ["view", "lock", "edit"]},
      %{section: "monthly_inputs", label: "Monthly Inputs", perms: ["view", "edit"]},
      %{section: "planning",       label: "Planning",       perms: ["view", "edit"]},
      %{section: "reports",        label: "Reports",        perms: ["view"]},
    ])
    |> assign(:perms, [
      %{permission: "view", label: "View"},
      %{permission: "lock", label: "Lock"},
      %{permission: "edit", label: "Edit"},
    ])
    |> fetch_items()
    |> fetch_locations()
    |> fetch_company_budgets()
    |> fetch_draft_types()
    |> fetch_drafts()
    |> fetch_user_permissions()
    |> res(:ok)
  end

  #permissions
  @impl true
  def handle_info({[:budget, :home_permission, :created], perm}, socket) do
    %{permissions: permissions, role_id: role_id} = socket.assigns
    cond do
      perm.role_id == role_id -> socket |> assign(:permissions, [perm | permissions] |> Enum.uniq_by(&(&1.id))) |> res()
      true -> socket |> res()
    end
  end
  @impl true
  def handle_info({[:budget, :home_permission, :updated], perm}, socket) do
    %{permissions: permissions} = socket.assigns
    socket |> assign(:permissions, Enum.map(permissions, &(if &1.id == perm.id, do: perm, else: &1))) |> res()
  end
  @impl true
  def handle_info({[:budget, :home_permission, :deleted], perm}, socket) do
    %{permissions: permissions} = socket.assigns
    socket |> assign(:permissions, Enum.reject(permissions, &(&1.id == perm.id))) |> res()
  end

  @impl true
  def handle_info({[:budget, _, _], _}, socket) do
    socket |> fetch_user_permissions() |> res()
  end

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("validate", params, socket) do
    %{changeset: changeset} = socket.assigns

    changeset =
      changeset.data
      |> @module.change(params |> Map.get(@key, %{}))
      |> Map.put(:action, :insert)

    socket
    |> assign(:changeset, changeset)
    |> res()
  end

  @impl true
  def handle_event("save", params, socket) do
    %{changeset: changeset} = socket.assigns

    changeset =
      changeset.data
      |> @module.change(params |> Map.get(@key, %{}))
      |> Map.put(:action, :insert)

    socket
    |> assign(:changeset, changeset)
    |> save()
    |> res()
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    changeset = id |> String.to_integer() |> @module.get() |> @module.change()
    socket |> assign(:changeset, changeset) |> assign(:new, false) |> res()
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    id |> String.to_integer() |> @module.delete()
    socket |> res()
  end

  @impl true
  def handle_event("cancel_edit", _, socket), do: socket |> assign(:changeset, @module.new_changeset) |> assign(:new, true) |> res()

  @impl true
  def handle_event("cancel", _, socket) do
    cancel(socket) |> res()
  end

  @impl true 
  def handle_event("select_company", _, socket) do
    %{expanded: expanded} = socket.assigns
    socket |> assign(:expanded, %{expanded | company: !expanded.company}) |> res()
  end

  @impl true 
  def handle_event("select_location", %{"id" => "0"}, socket) do
    %{expanded: expanded} = socket.assigns
    socket |> assign(:expanded, %{expanded | location: !expanded.location}) |> res()
  end
  @impl true 
  def handle_event("select_location", %{"id" => id}, socket) do
    %{expanded: expanded} = socket.assigns
    id = id |> String.to_integer()

    cond do
      Enum.any?(expanded.locations, &(&1 == id)) -> 
        socket 
        |> assign(:expanded, %{expanded | locations: (expanded.locations |> Enum.reject(&(&1 == id)))})
        |> res()
      true ->
        socket 
        |> assign(:expanded, %{expanded | locations: [id | expanded.locations]})
        |> res()
    end
  end

  @impl true 
  def handle_event("select_company_budget", %{"id" => "0"}, socket) do
    %{expanded: expanded} = socket.assigns
    socket |> assign(:expanded, %{expanded | company_budget: !expanded.company_budget}) |> res()
  end
  @impl true 
  def handle_event("select_company_budget", %{"id" => id}, socket) do
    %{expanded: expanded} = socket.assigns
    id = id |> String.to_integer()

    cond do
      Enum.any?(expanded.company_budgets, &(&1 == id)) -> 
        socket 
        |> assign(:expanded, %{expanded | company_budgets: (expanded.company_budgets |> Enum.reject(&(&1 == id)))})
        |> res()
      true ->
        socket 
        |> assign(:expanded, %{expanded | company_budgets: [id | expanded.company_budgets]})
        |> res()
    end
  end

  @impl true 
  def handle_event("select_draft_type", %{"id" => "0"}, socket) do
    %{expanded: expanded} = socket.assigns
    socket |> assign(:expanded, %{expanded | draft_type: !expanded.draft_type}) |> res()
  end
  @impl true 
  def handle_event("select_draft_type", %{"id" => id}, socket) do
    %{expanded: expanded} = socket.assigns
    id = id |> String.to_integer()

    cond do
      Enum.any?(expanded.draft_types, &(&1 == id)) -> 
        socket 
        |> assign(:expanded, %{expanded | draft_types: (expanded.draft_types |> Enum.reject(&(&1 == id)))})
        |> res()
      true ->
        socket 
        |> assign(:expanded, %{expanded | draft_types: [id | expanded.draft_types]})
        |> res()
    end
  end

  @impl true 
  def handle_event("select_draft", %{"id" => "0"}, socket) do
    %{expanded: expanded} = socket.assigns
    socket |> assign(:expanded, %{expanded | draft: !expanded.draft}) |> res()
  end
  @impl true 
  def handle_event("select_draft", %{"id" => id}, socket) do
    %{expanded: expanded} = socket.assigns
    id = id |> String.to_integer()

    cond do
      Enum.any?(expanded.drafts, &(&1 == id)) -> 
        socket 
        |> assign(:expanded, %{expanded | drafts: (expanded.drafts |> Enum.reject(&(&1 == id)))})
        |> res()
      true ->
        socket 
        |> assign(:expanded, %{expanded | drafts: [id | expanded.drafts]})
        |> res()
    end
  end

  @impl true
  def handle_event("deactivate", %{"permission" => perm, "section" => section} = params, socket) do
    %{
      company_id:  company_id,
      modal:       %{opts: %{user_id: user_id}},
      permissions: permissions,
      sections:    sections,
      role_id:     role_id,
    } = socket.assigns

    new_perm = 
      #perms
      sections
      |> Enum.find(fn s -> s.section == section end)
      |> Map.get(:perms)
      |> Enum.with_index()
      |> Enum.find({nil, nil}, fn {p, _} -> p == perm end)
      |> elem(1)
      |> case do
        0 -> nil
        i -> sections |> Enum.find(%{}, fn s -> s.section == section end) |> Map.get(:perms, []) |> Enum.at(i - 1)
      end

    location_id       = params |> Map.get("location_id",       "0") |> String.to_integer()
    company_budget_id = params |> Map.get("company_budget_id", "0") |> String.to_integer()
    draft_type_id     = params |> Map.get("draft_type_id",     "0") |> String.to_integer()
    draft_id          = params |> Map.get("draft_id",          "0") |> String.to_integer()

    cond do
      new_perm == nil -> 
        Enum.find(permissions, &(
          &1.section == section
          && ((is_nil(&1.location_id)       && location_id       == 0) || &1.location_id       == location_id)
          && ((is_nil(&1.company_budget_id) && company_budget_id == 0) || &1.company_budget_id == company_budget_id)
          && ((is_nil(&1.draft_type_id)     && draft_type_id     == 0) || &1.draft_type_id     == draft_type_id)
          && ((is_nil(&1.draft_id)          && draft_id          == 0) || &1.draft_id          == draft_id)
        ))
        |> @module.delete()
      true ->
        Enum.find(permissions, %{@module.new() | created_by_id: user_id}, &(
          &1.section == section
          && ((is_nil(&1.location_id)       && location_id       == 0) || &1.location_id       == location_id)
          && ((is_nil(&1.company_budget_id) && company_budget_id == 0) || &1.company_budget_id == company_budget_id)
          && ((is_nil(&1.draft_type_id)     && draft_type_id     == 0) || &1.draft_type_id     == draft_type_id)
          && ((is_nil(&1.draft_id)          && draft_id          == 0) || &1.draft_id          == draft_id)
        ))
        |> @module.create_or_update(
          %{
            company_id:    company_id,
            location_id:       (if location_id       == 0, do: nil, else: location_id),
            company_budget_id: (if company_budget_id == 0, do: nil, else: company_budget_id),
            draft_type_id:     (if draft_type_id     == 0, do: nil, else: draft_type_id),
            draft_id:          (if draft_id          == 0, do: nil, else: draft_id),
            role_id:       role_id,
            section:       section,
            permission:    new_perm,
            updated_by_id: user_id
          })
    end 
    socket |> res()
  end

  @impl true
  def handle_event("activate", %{"permission" => perm, "section" => section} = params, socket) do
    %{
      company_id:  company_id,
      modal:       %{opts: %{user_id: user_id}},
      permissions: permissions,
      role_id:     role_id,
    } = socket.assigns

    location_id       = params |> Map.get("location_id",       "0") |> String.to_integer()
    company_budget_id = params |> Map.get("company_budget_id", "0") |> String.to_integer()
    draft_type_id     = params |> Map.get("draft_type_id",     "0") |> String.to_integer()
    draft_id          = params |> Map.get("draft_id",          "0") |> String.to_integer()

    Enum.find(permissions, %{@module.new() | created_by_id: user_id}, &(
      &1.section == section
      && ((is_nil(&1.location_id)       && location_id       == 0) || &1.location_id       == location_id)
      && ((is_nil(&1.company_budget_id) && company_budget_id == 0) || &1.company_budget_id == company_budget_id)
      && ((is_nil(&1.draft_type_id)     && draft_type_id     == 0) || &1.draft_type_id     == draft_type_id)
      && ((is_nil(&1.draft_id)          && draft_id          == 0) || &1.draft_id          == draft_id)
    ))
    |> @module.create_or_update(
      %{
        company_id:        company_id,
        location_id:       (if location_id == 0,       do: nil, else: location_id),
        company_budget_id: (if company_budget_id == 0, do: nil, else: company_budget_id),
        draft_type_id:     (if draft_type_id == 0,     do: nil, else: draft_type_id),
        draft_id:          (if draft_id == 0,          do: nil, else: draft_id),
        role_id:           role_id,
        section:           section,
        permission:        perm,
        updated_by_id:     user_id
      })
    socket |> res()
  end

  @impl true
  def handle_event(event, params, socket) do
    print_unhandled(event, params, __MODULE__)
    socket |> res()
  end
end



