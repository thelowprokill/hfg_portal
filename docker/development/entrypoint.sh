#!/bin/bash
# Docker entrypoint script.

set -e

mix deps.get

# Wait for MySQL to become available
while ! mysql --host="$MYSQL_HOST" --user="$MYSQL_USERNAME" --password="$MYSQL_PASSWORD" -e "SELECT 1" >/dev/null 2>&1;
do
    echo "Waiting for MySQL to be available..."
    mysql --host="$MYSQL_HOST" --user="$MYSQL_USERNAME" --password="$MYSQL_PASSWORD" -e "SELECT 1"
    sleep 2
done

# All apps in umbrella
apps="hfg_portal car_maintenance loan_repayment wife_time"

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
