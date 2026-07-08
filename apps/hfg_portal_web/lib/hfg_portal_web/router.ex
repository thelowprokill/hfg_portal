defmodule HfgPortalWeb.Router do
  import Phoenix.LiveDashboard.Router
  use HfgPortalWeb, :router

  import HfgPortalWeb.CustomerAuth

  import HfgPortalWeb.ApiUserAuth

  import HfgPortalWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HfgPortalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_customer
    plug :fetch_current_api_user
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end



  # Other scopes may use custom stacks.
  # scope "/api", HfgPortalWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
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
      #forward "/mailbox", Plug.Swoosh.MailboxPreview
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
      live "/users/register",              UserRegistrationLive,   :new
      live "/users/log_in",                UserLoginLive,          :new
      live "/users/reset_password",        UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive,  :edit

      get "/auth/google/callback", GoogleAuthController, :index
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/", HfgPortalWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{HfgPortalWeb.UserAuth, :ensure_authenticated}] do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email


      live "/", Layout.SidebarLive
    end
  end

  scope "/", HfgPortalWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete

    live_session :current_user,
      on_mount: [{HfgPortalWeb.UserAuth, :mount_current_user}] do
      live "/users/confirm/:token", UserConfirmationLive, :edit
      live "/users/confirm", UserConfirmationInstructionsLive, :new
    end
  end

  ## Authentication routes

  scope "/", HfgPortalWeb do
    pipe_through [:browser, :redirect_if_api_user_is_authenticated]

    #get  "/api_users/register",              ApiUserRegistrationController,  :new
    #post "/api_users/register",              ApiUserRegistrationController,  :create
    get  "/api_users/log_in",                ApiUserSessionController,       :new
    post "/api_users/log_in",                ApiUserSessionController,       :create
    #get  "/api_users/reset_password",        ApiUserResetPasswordController, :new
    #post "/api_users/reset_password",        ApiUserResetPasswordController, :create
    #get  "/api_users/reset_password/:token", ApiUserResetPasswordController, :edit
    #put  "/api_users/reset_password/:token", ApiUserResetPasswordController, :update
  end

  scope "/", HfgPortalWeb do
    pipe_through [:browser, :require_authenticated_api_user]

    #get "/api_users/settings",                      ApiUserSettingsController, :edit
    #put "/api_users/settings",                      ApiUserSettingsController, :update
    #get "/api_users/settings/confirm_email/:token", ApiUserSettingsController, :confirm_email
  end

  scope "/", HfgPortalWeb do
    pipe_through [:browser]

    get "/car_maitenance_images/:id/image",  CarMaintenance.MaintenanceImageRenderController, :image
    delete "/api_users/log_out",        ApiUserSessionController,      :delete
    #get    "/api_users/confirm",        ApiUserConfirmationController, :new
    #post   "/api_users/confirm",        ApiUserConfirmationController, :create
    #get    "/api_users/confirm/:token", ApiUserConfirmationController, :edit
    #post   "/api_users/confirm/:token", ApiUserConfirmationController, :update
  end

  ## Authentication routes

  scope "/", HfgPortalWeb do
    pipe_through [:browser, :redirect_if_customer_is_authenticated]

    #get  "/customers/register",              CustomerRegistrationController,  :new
    #post "/customers/register",              CustomerRegistrationController,  :create
    get  "/customers/log_in",                CustomerSessionController,       :new
    post "/customers/log_in",                CustomerSessionController,       :create
    #get  "/customers/reset_password",        CustomerResetPasswordController, :new
    #post "/customers/reset_password",        CustomerResetPasswordController, :create
    #get  "/customers/reset_password/:token", CustomerResetPasswordController, :edit
    #put  "/customers/reset_password/:token", CustomerResetPasswordController, :update
  end

  scope "/", HfgPortalWeb do
    pipe_through [:browser, :require_authenticated_customer]

    #get "/customers/settings",                      CustomerSettingsController, :edit
    #put "/customers/settings",                      CustomerSettingsController, :update
    #get "/customers/settings/confirm_email/:token", CustomerSettingsController, :confirm_email
  end

  scope "/", HfgPortalWeb do
    pipe_through [:browser]

    delete "/customers/log_out",        CustomerSessionController,      :delete
    #get    "/customers/confirm",        CustomerConfirmationController, :new
    #post   "/customers/confirm",        CustomerConfirmationController, :create
    #get    "/customers/confirm/:token", CustomerConfirmationController, :edit
    #post   "/customers/confirm/:token", CustomerConfirmationController, :update
  end
end
