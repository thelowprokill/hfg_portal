defmodule HfgPortalWeb.Layout.SidebarLive do

  @doc """
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

  use HfgPortalWeb, :live_view

  alias HfgPortalWeb.Layout.UserSettings

  alias HfgPortal.Accounts
  alias HfgPortal.Helpers.{App, Page}

  # this is a copy of
  # https://github.com/aiwaiwa/phoenix_dark_mode
  def dark_mode_button(assigns) do
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

  defp list_apps(socket) do
    %{current_user: current_user} = socket.assigns
    system_apps = [
      %App{
        name: "Home",
        id: "home",
        module: HfgPortalWeb.Home.HomeLive,
      },
      %App{
        name: "Accounts",
        id: "accounts",
        links: HfgPortal.Authorize.list_pages(current_user),
      },
      #%App{
      #  name: "Admin Logs",
      #  id: "admin_logs",
      #  links: AdminLogs.Authorize.list_pages(current_user),
      #},
      %App{
        name: "Dev Tools", 
        id: "dev_tools",
        links: list_dev_tools(current_user),
      }
    ]

    apps = [
      %App{
        name: "Car Maintenance",
        id: "car_maintenance",
        links: CarMaintenance.Authorize.list_pages(current_user),
      },
      %App{
        name: "Loan Repayment",
        id: "loan_repayment",
        links: LoanRepayment.Authorize.list_pages(current_user),
      },

    ]
    
    #apps = cond do
    #  true ->
    #    [
    #      %App{
    #        name: "Budget",
    #        id: "budget",
    #        links: Budget.Authorize.list_pages(current_user),
    #        show_admin: Budget.Admins.is_admin(current_user.id),
    #      },
    #      %App{
    #        name: "Dev Team Timetracking",
    #        id:   "dev_team_timetracking",
    #        links: DevTeamTimetracking.Authorize.list_pages(current_user),
    #      },
    #      %App{
    #        name: "IT Budget",
    #        id: "it_budget",
    #        links: ItBudget.Authorize.list_pages(current_user),
    #        show_admin: false,
    #      },
    #    ]
    #end

    assign(socket, :apps, system_apps ++ apps)
  end

  defp update_app(socket, app, links, show_admin) do
    socket 
    |> assign(:apps, Enum.map(socket.assigns.apps, &if(&1.id == app, do: Map.put(&1, :links, links) |> Map.put(:show_admin, show_admin), else: &1)))
    |> case do
      socket when socket.assigns.selected_app == app -> socket |> redraw()
      socket -> socket
    end
  end

  defp list_dev_tools(%{dev_admin: true, admin_mode: true}) do
    [
      %Page{id: "button_gallery",  name: "Button Gallery",  module: HfgPortalWeb.DevTools.ButtonGallery.ButtonGalleryLive},          
      %Page{id: "icon_gallery",    name: "Icon Gallery",    module: HfgPortalWeb.DevTools.IconGallery.IconGallery},
      %Page{id: "infinite_scroll", name: "Infinite Scroll", module: HfgPortalWeb.DevTools.InfiniteScroll.InfiniteScrollLive},
      %Page{id: "input_gallery",   name: "Input Gallery",   module: HfgPortalWeb.DevTools.InputGallery.InputGalleryLive},
    ]
  end
  defp list_dev_tools(_), do: []

  defp set_modal(socket, modal \\ nil)
  defp set_modal(socket, :user_settings) do
    %{modal_stack: modal_stack} = socket.assigns

    socket
    |> assign(:modal_stack, [%{
      modal:  :user_settings,
      module: UserSettings,
      id:     :user_settings,
      user:   socket.assigns.current_user
    } | modal_stack])
  end
  defp set_modal(socket, _), do: socket |> assign(:modal_stack, stack_pop(socket.assigns.modal_stack))

  defp redirect_to(socket, app, link) do
    %{apps: apps} = socket.assigns

    {module, error} = 
      apps
      |> Enum.find(%{links: []}, &(&1.id == app))
      |> Map.get(:links)
      |> fn x -> Enum.find(x, Map.put(Enum.at(x, 0, %{module: HfgPortalWeb.Home.HomeLive}), :error, :error), &(&1.id == link)) end.()
      #|> Map.get(:module)
      |> fn x -> {Map.get(x, :module), Map.get(x, :error)} end.()

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
    %{
      selected_app:   selected_app,
      apps:           apps,
      page:           page,
      render_success: render_success
    } = socket.assigns
    cond do
      # this is to check if the user still has access to the page they are on.
      # If they do. don't do anything here.
      # If they don't, redirect.
      render_success && Enum.find(apps, %{links: []}, &(&1.id == selected_app)) |> Map.get(:links) |> Enum.find(&(&1.id == page)) -> socket
      true ->
        address = 
          Enum.reduce(socket.assigns.session, "/?", fn {k, v}, acc -> "#{acc}#{k}=#{v}&" end)
          |> fn x -> String.slice(x, 0, String.length(x) - 1) end.()
        push_navigate(socket, to: address)
    end
  end

  @impl true
  def mount(_session, session, socket) do
    if connected?(socket) do
      Accounts.subscribe()
      #ItBudget.UserRoles.subscribe()
      #Budget.Admins.subscribe()
      #Budget.UserRoles.subscribe()
      #Budget.Roles.subscribe()
      #Budget.CompanyPermissions.subscribe()
      #Budget.HomePermissions.subscribe()
      #DevTeamTimetracking.UserRoles.subscribe()
    end

    socket
    |> bnw_verify_user_token_side_bar(session)
    #|> set_modal()
    |> assign(:modal_stack,    [])
    |> assign(:selected_app,   nil)
    |> assign(:page,           nil)
    |> assign(:show_sidebar,   true)
    |> assign(:session,        %{})
    |> assign(:module,         HfgPortalWeb.Home.HomeLive)
    |> assign(:render_success, false)
    |> list_apps()
    |> res(:ok)
  end

  @impl true
  def handle_params(%{"admin" => admin} = session, uri, socket) do
    %{session: stored_session} = socket.assigns

    socket =
      socket
      |> assign(:current_user, %{socket.assigns.current_user | admin_mode: admin == "true"})
      |> assign(:session, Map.merge(stored_session, %{"admin" => admin}))
      |> list_apps()

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
    %{session: stored_session, selected_app: selected_app} = socket.assigns

    socket =
      socket 
      |> assign(:session, Map.merge(stored_session, %{"page" => page}))
      |> assign(:page, page)
      |> redirect_to(selected_app, page) 

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
  def handle_event("select_app", %{"app" => app}, socket) do
    %{selected_app: selected_app} = socket.assigns
    socket
    |> assign(:selected_app, (if app == selected_app, do: nil, else: app))
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
