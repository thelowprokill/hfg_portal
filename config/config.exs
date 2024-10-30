# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configure Mix tasks and generators
config :wife_time,
  ecto_repos: [WifeTime.Repo]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :wife_time, WifeTime.Mailer, adapter: Swoosh.Adapters.Local

# Configure Mix tasks and generators
config :loan_repayment,
  ecto_repos: [LoanRepayment.Repo]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :loan_repayment, LoanRepayment.Mailer, adapter: Swoosh.Adapters.Local

# Configure Mix tasks and generators
config :car_maintenance,
  ecto_repos: [CarMaintenance.Repo]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :car_maintenance, CarMaintenance.Mailer, adapter: Swoosh.Adapters.Local

# Configure Mix tasks and generators
config :hfg_portal,
  ecto_repos: [HfgPortal.Repo]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :hfg_portal, HfgPortal.Mailer, adapter: Swoosh.Adapters.Local

config :hfg_portal_web,
  ecto_repos: [HfgPortal.Repo],
  generators: [context_app: :hfg_portal]

# Configures the endpoint
config :hfg_portal_web, HfgPortalWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: HfgPortalWeb.ErrorHTML, json: HfgPortalWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: HfgPortal.PubSub,
  live_view: [signing_salt: "1Qb4ZL3I"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/hfg_portal_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/hfg_portal_web/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Google Auth
config :elixir_auth_google,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
