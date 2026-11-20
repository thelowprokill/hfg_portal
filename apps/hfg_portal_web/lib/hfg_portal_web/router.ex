defmodule HfgPortalWeb.Router do
  import Phoenix.LiveDashboard.Router
  use HfgPortalWeb, :router

  import HfgPortalWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HfgPortalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end



  # Other scopes may use custom stacks.
  # scope "/api", HfgPortalWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:hfg_portal_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HfgPortalWeb.Telemetry
    end
  end

  ## API Routes
  scope "/apis", HfgPortalWeb do
    pipe_through :api
    get    "/call", Apis.RoutesController, :call
    put    "/call", Apis.RoutesController, :call
    delete "/call", Apis.RoutesController, :call
  end
  scope "/apis/task_automation_controller/update", HfgPortalWeb do
    pipe_through :api
    get "/", Apis.TaskAutomationControllerApiController, :update
  end

  ## Authentication routes

  scope "/", HfgPortalWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{HfgPortalWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", HfgPortalWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{HfgPortalWeb.UserAuth, :ensure_authenticated}] do
      live "/", Layout.SidebarLive
    end

    get "/car_maintenance_images/:id/image", CarMaintenance.MaintenanceImageRenderController, :image
  end

  scope "/", HfgPortalWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
  end
end
