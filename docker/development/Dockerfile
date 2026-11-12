# ./Dockerfile

# Extend from the official Elixir image.
FROM elixir:1.15.6-slim

ENV REFRESH_TOKEN="0"

RUN apt-get update && \
    apt-get install -y default-mysql-client postgresql-client inotify-tools build-essential && \
    rm -rf /var/lib/apt/lists/*

# Create app directory and copy the Elixir projects into it.
RUN mkdir /app
COPY . /app
WORKDIR /app

# Install Hex package manager.
# By using `--force`, we don’t need to type “Y” to confirm the installation.
RUN mix local.hex --force && \
    mix local.rebar --force

# Install dependencies
RUN mix deps.get
RUN mix deps.compile

# Compile the project
RUN mix compile

# Digest the static assets
RUN mix phx.digest

# Make port 4000 available to the world outside this container
EXPOSE 4000

COPY /docker/development/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]
