import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  mysql_host =
    System.get_env("MYSQL_HOST") ||
      raise """
      environment variable MYSQL_HOST is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  mysql_username =
    System.get_env("MYSQL_USERNAME") ||
      raise """
      environment variable MYSQL_USERNAME is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  mysql_password =
    System.get_env("MYSQL_PASSWORD") ||
      raise """
      environment variable MYSQL_PASSWORD is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  mysql_port = (System.get_env("MYSQL_PORT") || "3306") |> String.to_integer()

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :budget, Budget.Repo,
    # ssl: true,
    hostname: mysql_host,
    username: mysql_username,
    password: mysql_password,
    port:     mysql_port,
    database: "hfg_portal_budget",
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :wife_time, WifeTime.Repo,
    # ssl: true,
    hostname: mysql_host,
    username: mysql_username,
    password: mysql_password,
    port:     mysql_port,
    database: "hfg_portal_wife_time",
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :car_maintenance, CarMaintenance.Repo,
    # ssl: true,
    hostname: mysql_host,
    username: mysql_username,
    password: mysql_password,
    port:     mysql_port,
    database: "hfg_portal_car_maintenance",
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :loan_repayment, LoanRepayment.Repo,
    # ssl: true,
    hostname: mysql_host,
    username: mysql_username,
    password: mysql_password,
    port:     mysql_port,
    database: "hfg_portal_loan_repayment",
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :timekeeping, Timekeeping.Repo,
    # ssl: true,
    hostname: mysql_host,
    username: mysql_username,
    password: mysql_password,
    port:     mysql_port,
    database: "hfg_portal_timekeeping",
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  config :hfg_portal, HfgPortal.Repo,
    # ssl: true,
    hostname: mysql_host,
    username: mysql_username,
    password: mysql_password,
    port:     mysql_port,
    database: "hfg_portal",
    pool_size: String.to_integer(System.get_env("MYSQL_POOL_SIZE") || "10"),
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  config :hfg_portal_web, :environment, System.get_env("ENVIRONMENT") || "production"

  config :hfg_portal_web, HfgPortalWeb.Endpoint,
    server: true,
    # https: [
    #  port: String.to_integer(System.get_env("PORT") || "4000"),
    #  cipher_suite: :strong,
    #  # TODO
    #  # fix this. for some reason it is not working with my cert bot certification
    #  # keyfile:  System.get_env("SSL_KEY"),
    #  # certfile: System.get_env("SSL_CERT"),
    #  keyfile: "priv/cert/selfsigned_key.pem",
    #  certfile: "priv/cert/selfsigned.pem"
    # ],
    http: [
      port: String.to_integer(System.get_env("PORT") || "4000")
    ],
    # http: [
    # # Enable IPv6 and bind on all interfaces.
    # # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
    # ip: {0, 0, 0, 0, 0, 0, 0, 0},
    # port: String.to_integer(System.get_env("PORT") || "4000")
    # ],
    url: [
      host: System.get_env("HOSTNAME") || "localhost",
      port:
        String.to_integer(System.get_env("EXTERNAL_PORT") || System.get_env("PORT") || "4000"),
      scheme: System.get_env("URL_SCHEME") || "http"
    ],
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :hfg_portal_web, HfgPortalWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :hfg_portal_web, HfgPortalWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :hfg_portal_web, HfgPortalWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :hfg_portal, HfgPortal.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
