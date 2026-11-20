#!/bin/bash
# Docker entrypoint script.

set -e

mix deps.get
# Dependency compile output (their warnings) is hidden; the log is printed only if it fails.
mix deps.compile > /tmp/deps_compile.log 2>&1 || (cat /tmp/deps_compile.log; exit 1)

# Wait for Postgres to become available
export PGPASSWORD="$POSTGRES_PASSWORD"
while ! pg_isready --host="$POSTGRES_HOST" --username="$POSTGRES_USERNAME" >/dev/null 2>&1;
do
    echo "Waiting for Postgres to be available..."
    sleep 2
done

# All apps in umbrella
apps="hfg_portal car_maintenance loan_repayment wife_time budget timekeeping homm_saves task_automation_controller"

# Create, migrate, and seed database if it doesn't exist.
echo ""
echo ""
echo ""
echo "Migrating and seeding databases..."
echo ""
echo ""
echo ""
for app in $apps; 
do
    echo "Database $app does not exist. Creating..."
    mix cmd --app $app mix ecto.create
    echo "Database $app created."
    echo "Migrating $app..."
    mix cmd --app $app mix ecto.migrate
    echo "Migrating $app complete."
    echo "Seeding $app..."
    mix cmd --app $app mix run priv/repo/seeds.exs 
    echo "Seeding $app complete."
done
echo ""
echo ""
echo ""
echo "Done Migrating and seeding databases..."
echo ""
echo ""
echo ""

exec mix phx.server
