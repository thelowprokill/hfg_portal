defmodule HfgPortalWeb.Layout.SidebarLive do
  @moduledoc """
  To add a new app to the side bar:

  Create the function App.Authorize.list_pages/1

  Add the app to the list_apps/1 function
  This should be formated as
  %{
    name: "My App",
    id: "my_app",
    links: app.Authorize.list_pages(current_user)
  }

  For live update add a handle_info/2
  @impl true
  # this has three options in the [] because this makes it so that SidebarLive can tell what apps permission has been updated.
  def handle_info({[:my_app, :user_role, _], user_role}, socket) do
    cond do
      user_role.user_id == socket.assigns.current_user.id -
        update_app(socket, "my_app", app.Authorize.list_pages(socket.assigns.current_user))
      true -> socket
    end
  end

  This will automatically redirect to the home page if the user does not have access to the page.
  This will not automatically set in page permissions.
  """

  @depths ["pl-2", "pl-6", "pl-10", "pl-14"]

  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Layout.UserSettings

  alias HfgPortal.Accounts
  alias HfgPortal.Helpers.Page

  # this is a copy of
  # https://github.com/aiwaiwa/phoenix_dark_mode
  defp dark_mode_button(assigns) do
    ~H"""
    <button
      id="theme-toggle"
      type="button"
      phx-update="ignore"
      phx-hook="DarkThemeToggle"
      class="text-zinc-500 dark:text-zinc-400 hover:bg-zinc-100 dark:hover:bg-zinc-700 rounded-lg text-sm p-2"
    >
      <.bnw_icon bnw_icon="moon" fill="currentColor" class="text-transparent hidden" id="theme-toggle-dark-icon" />
      <.bnw_icon bnw_icon="sun"  fill="currentColor" class="text-transparent hidden" id="theme-toggle-light-icon" />
    </button>

    <script>
      // Toggle early based on <html class="dark">
      const themeToggleDarkIcon = document.getElementById('theme-toggle-dark-icon');
      const themeToggleLightIcon = document.getElementById('theme-toggle-light-icon');
      if (themeToggleDarkIcon != null && themeToggleLightIcon != null) {
        let dark = document.documentElement.classList.contains('dark');
        const show = dark ? themeToggleDarkIcon : themeToggleLightIcon
        const hide = dark ? themeToggleLightIcon : themeToggleDarkIcon
        show.classList.remove('hidden', 'text-transparent');
        hide.classList.add('hidden', 'text-transparent');
      }
    </script>
    """
  end

  attr :page,          :map,    required: true
  attr :current_user,  :map,    required: true
  attr :selected_page, :list,   required: true
  attr :depth,         :list,   default: []
  attr :link,          :string, default: ""
  defp page_links(%{page: %{links: links}} = assigns) when is_list(links) and length(links) > 0 do
    ~H"""
      <a phx-click="select_section"
         phx-value-link={"#{if(@link == "", do: "", else: "#{@link},")}#{@page.id}"}
         class={"
           cursor-pointer
           flex
           items-center
           p-2
           #{Enum.at(@depth, 0)}
           #{if length(@depth) == 0, do: "border-2 border-black"}
           text-gray-900
           rounded-lg
           dark:text-white
           hover:bg-gray-100
           dark:hover:bg-gray-700
         "}>
        <%= @page.name %>
      </a>
      <%= if @page.id == Enum.at(@selected_page, 0) do %>
        <ul>
          <%= for link <- @page.links do %>
            <li>
              <.page_links
                page={link}
                current_user={@current_user}
                selected_page={Enum.slice(@selected_page, 1..-1//1)}
                depth={Enum.slice(@depth, 1..-1//1)}
                link={"#{if(@link == "", do: "", else: "#{@link},")}#{@page.id}"}
              />
            </li>
          <% end %>
        </ul>
      <% end %>
    """
  end
  defp page_links(%{page: %{module: module}} = assigns) when not is_nil(module) do
    ~H"""
      <.link
         class={"
           flex
           items-center
           p-2
           #{Enum.at(@depth, 0)}
           #{if length(@depth) == 0, do: "border-2 border-black"}
           text-gray-900
           rounded-lg
           dark:text-white
           hover:bg-gray-100
           dark:hover:bg-gray-700"}
        
        navigate={"/?page=#{if(@link == "", do: "", else: "#{@link},")}#{@page.id}#{if @current_user.admin_mode, do: "&admin=true"}"}>
        <%= @page.name %>
      </.link>
    """
  end
  defp page_links(assigns) do
    ~H"""
    """
  end

  def list_apps(current_user) do
    system_apps = [
      %Page{
        name: "Home",
        id: "home",
        module: HfgPortalWeb.Home.HomeLive,
      },
      %Page{
        name: "Accounts",
        id: "accounts",
        links: HfgPortal.Authorize.list_pages(current_user),
      },
      #%App{
      #  name: "Admin Logs",
      #  id: "admin_logs",
      #  links: AdminLogs.Authorize.list_pages(current_user),
      #},
      %Page{
        name: "Dev Tools",
        id: "dev_tools",
        links: list_dev_tools(current_user),
      }
    ]

    apps = [
      %Page{
        name: "Budget",
        id: "budget",
        links: Budget.Authorize.list_pages(current_user),
      },
      %Page{
        name: "Car Maintenance",
        id: "car_maintenance",
        links: CarMaintenance.Authorize.list_pages(current_user),
      },
      %Page{
        name: "Loan Repayment",
        id: "loan_repayment",
        links: LoanRepayment.Authorize.list_pages(current_user),
      },
      %Page{
        name: "Wife Time",
        id: "wife_time",
        links: WifeTime.Authorize.list_pages(current_user),
      },
      %Page{
        name: "Timekeeping",
        id: "timekeeping",
        links: Timekeeping.Authorize.list_pages(current_user),
      },
      %Page{
        name: "Task Automation",
        id: "task_automation_controller",
        links: TaskAutomationController.Authorize.list_pages(current_user),
      },
    ]

    system_apps ++ apps
  end

  defp assign_apps(socket) do
    assign(socket, :apps, list_apps(socket.assigns.current_user))
  end

  defp update_app(socket, app, links, show_admin) do
    socket = socket
    |> assign(:apps, Enum.map(socket.assigns.apps, &if(&1.id == app, do: Map.put(&1, :links, links) |> Map.put(:show_admin, show_admin), else: &1)))

    selected_app  = Map.get(socket.assigns, :selected_app)
    selected_page = Map.get(socket.assigns, :selected_page, [])

    if selected_app == app || List.first(selected_page) == app,
      do:   redraw(socket),
      else: socket
  end

  defp list_dev_tools(%{dev_admin: true, admin_mode: true}) do
    [
      %Page{id: "expand",          name: "Expand",          links: [
        %Page{id: "archive",         name: "Archive",         module: HfgPortalWeb.DevTools.Archive.ArchiveLive},
        %Page{id: "button_gallery",  name: "Button Gallery",  module: HfgPortalWeb.DevTools.ButtonGallery.ButtonGalleryLive},
        %Page{id: "icon_gallery",    name: "Icon Gallery",    module: HfgPortalWeb.DevTools.IconGallery.IconGallery},
      ]},
      %Page{id: "infinite_scroll", name: "Infinite Scroll", module: HfgPortalWeb.DevTools.InfiniteScroll.InfiniteScrollLive},
      %Page{id: "input_gallery",   name: "Input Gallery",   module: HfgPortalWeb.DevTools.InputGallery.InputGalleryLive},
      #%Page{id: "streamlit_test",  name: "Streamlit Test",  module: HfgPortalWeb.DevTools.StreamlitTest.StreamlitTestLive},
    ]
  end
  defp list_dev_tools(_), do: []

  defp set_modal(socket, modal \\ nil)
  defp set_modal(socket, :user_settings) do
    %{modal_stack: modal_stack, jwt_token: jwt_token} = socket.assigns

    socket
    |> assign(:modal_stack, [%{
      modal:  :user_settings,
      module: UserSettings,
      id:     :user_settings,
      user:   socket.assigns.current_user,
      opts:   %{jwt: jwt_token}
    } | modal_stack])
  end
  defp set_modal(socket, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  defp find_page(pages, selected_page) do
    page = 
      pages
      |> Enum.find(&(&1.id == Enum.at(selected_page, 0)))
    
    cond do
      page && length(selected_page) == 1 -> {page.module, nil}
      page && length(selected_page) > 1 && length(page.links) > 0 -> find_page(page.links, Enum.slice(selected_page, 1..-1//1))
      true -> {HfgPortalWeb.Home.HomeLive, :error}
    end
  end

  defp redirect_to(socket) do
    %{apps: apps, selected_page: selected_page} = socket.assigns

    {module, error} = find_page(apps, selected_page)

    #UserPageLogs.new()
    #|> UserPageLogs.create_or_update(
    #  %{
    #  user_id: socket.assigns.current_user.id,
    #  page:    Enum.join(selected_page, ","),
    #  params:  session |> Map.drop(["page"]) |> Enum.map(fn {k, v} -> "#{k}=#{v}" end) |> Enum.join("&"),
    #  success: is_nil(error)
    #})

    socket
    |> assign(:module, module)
    |> assign(:render_success, is_nil(error))
    #|> fn x -> if !is_nil(error), do: put_flash(x, :error, "Page not available"), else: x end.()
    |> put_flash(error, "The page you requested does not exist or you lack the permissions to access it.")
  end

  defp redirect_to(socket, app) do
    %{apps: apps} = socket.assigns

    module =
      apps
      |> Enum.find(%{links: []}, &(&1.id == app))
      |> Map.get(:module)

    cond do
      module -> socket |> assign(:module, module)
      true   -> socket
    end
  end

  defp redraw(socket) do
    apps          = socket.assigns.apps
    selected_app  = Map.get(socket.assigns, :selected_app)
    selected_page = Map.get(socket.assigns, :selected_page, [])

    # Build the full page path. When navigating via the sidebar, selected_page
    # already includes the app prefix (e.g. ["budget", "dashboard"]).  When
    # navigating via a child LiveView push_patch, selected_app is set separately
    # and selected_page contains only the leaf (e.g. ["dashboard"]).
    full_path =
      if not is_nil(selected_app) and List.first(selected_page) != selected_app,
        do:   [selected_app | selected_page],
        else: selected_page

    {_module, error} = find_page(apps, full_path)

    if is_nil(error) do
      socket
    else
      address =
        Enum.reduce(socket.assigns.session, "/?", fn {k, v}, acc -> "#{acc}#{k}=#{v}&" end)
        |> fn x -> String.slice(x, 0, String.length(x) - 1) end.()
      push_navigate(socket, to: address)
    end
  end

  defp generate_token(socket) do
    %{current_user: %{id: user_id}} = socket.assigns

    token_config = Map.put(%{}, "scope", %Joken.Claim{
      generate: fn -> "user" end,
      validate: fn val, _claims, _context -> val in ["u", "a"] end
    })
    signer = Joken.Signer.create("HS256", System.get_env("JWT_SECRET"))

    {:ok, claims} = Joken.generate_claims(token_config, %{
      user_id:    user_id,
      admin:      false,
      updated_at: DateTime.utc_now() |> Calendar.strftime("%Y-%m-%dT%H:%M:%S"),
    })
    {:ok, jwt, _claims} = Joken.encode_and_sign(claims, signer)
    socket
    |> assign(:jwt_token, jwt)
  end

  @impl true
  def mount(_session, session, socket) do
    if connected?(socket) do
      Accounts.subscribe()

      CarMaintenance.UserRoles.subscribe()
      LoanRepayment.UserRoles.subscribe()
      WifeTime.UserRoles.subscribe()
      Budget.UserRoles.subscribe()
      Timekeeping.UserRoles.subscribe()
      TaskAutomationController.UserRoles.subscribe()
    end

    socket
    |> bnw_verify_user_token_side_bar(session)
    #|> set_modal()
    |> assign(:modal_stack,    [])
    |> assign(:selected_page,  [])
    |> assign(:show_sidebar,   true)
    |> assign(:session,        %{})
    |> assign(:depths,         @depths)
    |> assign(:module,         HfgPortalWeb.Home.HomeLive)
    |> assign(:render_success, false)
    |> assign_apps()
    |> generate_token()
    |> res(:ok)
  end

  @impl true
  def handle_params(%{"admin" => admin} = session, uri, socket) do
    %{session: stored_session} = socket.assigns

    socket =
      socket
      |> assign(:current_user, %{socket.assigns.current_user | admin_mode: admin == "true"})
      |> assign(:session, Map.merge(stored_session, %{"admin" => admin}))
      |> assign_apps()

    handle_params(session |> Map.delete("admin"), uri, socket)
  end

  @impl true
  def handle_params(%{"app" => app} = session, uri, socket) do
    %{session: stored_session} = socket.assigns
    socket =
      socket
      |> assign(:selected_app, app)
      |> assign(:session, Map.merge(stored_session, %{"app" => app}))
      |> redirect_to(app)

    handle_params(session |> Map.delete("app"), uri, socket)
  end

  @impl true
  def handle_params(%{"page" => page} = session, uri, socket) do
    %{session: stored_session} = socket.assigns

    socket =
      socket
      |> assign(:session, Map.merge(stored_session, %{"page" => page}))
      |> assign(:selected_page, page |> String.split(","))
      |> redirect_to()

    handle_params(session |> Map.delete("page"), uri, socket)
  end

  @impl true
  def handle_params(session, _uri, socket) do
    %{session: stored_session} = socket.assigns

    socket
    |> assign(:session, Map.merge(session, stored_session))
    |> res()
  end

  @impl true
  def handle_info(:cancel, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_info({[:user, :updated], user}, socket) do
    %{current_user: current_user} = socket.assigns

    cond do
      current_user.id == user.id -> socket |> assign(:current_user, user) |> res()
      true -> socket |> res()
    end
  end

  #################################################################################
  # App user role updates                                                         #
  #################################################################################

  @impl true
  def handle_info({[:timekeeping, :user_role, _], user_role}, socket) do
    cond do
      user_role.user_id == socket.assigns.current_user.id ->
        update_app(socket, "timekeeping", Timekeeping.Authorize.list_pages(socket.assigns.current_user), false)
      true -> socket
    end
    |> res()
  end

  @impl true
  def handle_info({[:task_automation_controller, :user_role, _], user_role}, socket) do
    cond do
      user_role.user_id == socket.assigns.current_user.id ->
        update_app(socket, "task_automation_controller", TaskAutomationController.Authorize.list_pages(socket.assigns.current_user), false)
      true -> socket
    end
    |> res()
  end

  @impl true
  def handle_info({[:budget, :user_role, _], user_role}, socket) do
    cond do
      user_role.user_id == socket.assigns.current_user.id ->
        update_app(socket, "budget", Budget.Authorize.list_pages(socket.assigns.current_user), false)
      true -> socket
    end
    |> res()
  end

  @impl true
  def handle_info({[:car_maintenance, :user_role, _], user_role}, socket) do
    cond do
      user_role.user_id == socket.assigns.current_user.id ->
        update_app(socket, "car_maintenance", CarMaintenance.Authorize.list_pages(socket.assigns.current_user), false)
      true -> socket
    end
    |> res()
  end

  @impl true
  def handle_info({[:loan_repayment, :user_role, _], user_role}, socket) do
    cond do
      user_role.user_id == socket.assigns.current_user.id ->
        update_app(socket, "loan_repayment", LoanRepayment.Authorize.list_pages(socket.assigns.current_user), false)
      true -> socket
    end
    |> res()
  end

  @impl true
  def handle_info({[:wife_time, :user_role, _], user_role}, socket) do
    cond do
      user_role.user_id == socket.assigns.current_user.id ->
        update_app(socket, "wife_time", WifeTime.Authorize.list_pages(socket.assigns.current_user), false)
      true -> socket
    end
    |> res()
  end

  #################################################################################
  # App user role updates                                                         #
  #################################################################################

  @impl true
  def handle_info({[:user, _], user}, socket) do
    cond do
      user.id == socket.assigns.current_user.id ->
        # do stuff if the user has changed.
        socket
      true -> socket
    end
    |> res()
  end

  @impl true
  def handle_info(info, socket) do
    print_unhandled(info, __MODULE__)
    socket |> res()
  end

  @impl true
  def handle_event("cancel", _, socket), do: socket |> set_modal() |> res()

  @impl true
  def handle_event("select_section", %{"link" => link}, socket) do
    %{selected_page: selected_page} = socket.assigns

    link = link |> String.split(",")
    temp_link = 
      link
      |> Enum.zip(selected_page)

    link = cond do
      !Enum.any?(temp_link, fn {x, y} -> x != y end) && length(link) <= length(selected_page) && length(selected_page) > 0 -> temp_link |> Enum.unzip() |> fn {x, _} -> x |> Enum.slice(0..-2) end.()
      true -> link
    end

    socket
    |> assign(:selected_page, link)
    |> res()
  end

  @impl true
  def handle_event("hide_sidebar", _, socket) do
    socket
    |> assign(:show_sidebar, false)
    |> res()
  end

  @impl true
  def handle_event("show_sidebar", _, socket) do
    socket
    |> assign(:show_sidebar, true)
    |> res()
  end

  @impl true
  def handle_event("edit_user_settings", _, socket) do
    socket
    |> set_modal(:user_settings)
    |> res()
  end

  @impl true
  def handle_event("toggle_admin_mode", _, socket) do
    %{
      current_user: %{admin_mode: admin_mode},
      session: stored_session
    } = socket.assigns

    socket
    |> assign(:session,
      stored_session
      |> Map.delete("admin")
      |> fn x -> if !admin_mode, do: Map.put(x, "admin", "true"), else: x end.()
    )
    |> push_changes()
    |> res()
  end

  @impl true
  def handle_event("sign_out", _, socket) do
    redirect(socket, to: ~p"/users/log_out", method: "delete") |> res()
  end

  @impl true
  def handle_event(event, session, socket) do
    print_unhandled(event, session, __MODULE__)
    socket |> res()
  end
end
