import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :budget, Budget.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hfg_portal_test#{System.get_env("MIX_TEST_PARTITION")}",
  migration_default_prefix: "budget_test",
  migration_source: "budget_schema_migrations",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :wife_time, WifeTime.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hfg_portal_test#{System.get_env("MIX_TEST_PARTITION")}",
  migration_default_prefix: "wife_time_test",
  migration_source: "wife_time_schema_migrations",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :loan_repayment, LoanRepayment.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hfg_portal_test#{System.get_env("MIX_TEST_PARTITION")}",
  migration_default_prefix: "loan_repayment_test",
  migration_source: "loan_repayment_schema_migrations",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :timekeeping, Timekeeping.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hfg_portal_test#{System.get_env("MIX_TEST_PARTITION")}",
  migration_default_prefix: "timekeeping_test",
  migration_source: "timekeeping_schema_migrations",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :car_maintenance, CarMaintenance.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hfg_portal_test#{System.get_env("MIX_TEST_PARTITION")}",
  migration_default_prefix: "car_maintenance_test",
  migration_source: "car_maintenance_schema_migrations",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :dev_team_timetracking, DevTeamTimetracking.Repo,
  username: "root",
  password: "",
  hostname: "localhost",
  database: "dev_team_timetracking_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :admin_logs, AdminLogs.Repo,
  username: "root",
  password: "",
  hostname: "localhost",
  database: "admin_logs_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :it_budget, ItBudget.Repo,
  username: "root",
  password: "",
  hostname: "localhost",
  database: "it_budget_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :budget, Budget.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hfg_portal_test#{System.get_env("MIX_TEST_PARTITION")}",
  migration_default_prefix: "budget_test",
  migration_source: "budget_schema_migrations",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :hfg_portal, HfgPortal.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hfg_portal_test#{System.get_env("MIX_TEST_PARTITION")}",
  migration_default_prefix: "hfg_portal_test",
  migration_source: "hfg_portal_schema_migrations",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :hfg_portal_web, HfgPortalWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "7+CnWBJ+H6Q9iGsjp+rZJYnT9KNf3cd4AWzh+K6RDDgsvWSDEpDAvE4szkNO1Oda",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# In test we don't send emails.
config :hfg_portal, HfgPortal.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

config :budget, env: :test
config :timekeeping, env: :test
