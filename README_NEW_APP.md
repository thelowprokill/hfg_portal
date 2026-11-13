# HfgPortal.Umbrella
dc run -w /app/apps app mix phx.new.ecto $name --database postgres

set username, password, hostname, and database in config/dev.exs
  username: System.get_env("POSTGRES_USERNAME", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST",     "localhost"),
  database: "hfg_portal_$name",

sudo chown -R $USER:$USER .

add config :$name, env: :dev to the end of config/dev.exs

add :$name to @apps in apps/hfg_portal/lib/hfg_portal/release.ex

add $name to docker/development/entrypoint.sh

dc up
