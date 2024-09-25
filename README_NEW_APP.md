# HfgPortal.Umbrella
dc run -w /app/apps app mix phx.new.ecto $name --database mysql

set username, password, hostname, and database in config/dev.exs
  username: System.get_env("MYSQL_USER",     "root"),
  password: System.get_env("MYSQL_PASSWORD", "root"),
  hostname: System.get_env("MYSQL_HOST",     "localhost"),
  database: "hfg_portal_$name",

sudo chown -R $USER:$USER .

add config :$name, env: :dev to the end of config/dev.exs

add :$name to @apps in apps/hfg_portal/lib/hfg_portal/release.ex

add $name to docker/development/entrypoint.sh

dc up
