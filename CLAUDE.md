# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Dependencies & setup
mix deps.get
mix setup              # Full dev setup: deps + DB create/migrate/seed

# Database
mix ecto.create
mix ecto.migrate
mix ecto.reset         # Drop, create, migrate, seed

# Dev server
mix phx.server         # Starts on port 4000 (exposed as 5000 in Docker)
docker-compose up      # Full dev env with Postgres 16 (MySQL 8.1 kept alongside for data migration)

# Testing
mix test               # Runs all tests across all umbrella apps
mix test apps/hfg_portal_web/test/controllers/user_session_controller_test.exs  # Single file

# Assets
mix assets.setup       # Install Tailwind + esbuild
mix assets.build       # Compile CSS/JS
mix assets.deploy      # Minified for production (includes phx.digest)

# Code format
mix format

# Production
mix release
```

In production, DB migrations are run via `HfgPortal.Release.migrate/0` (not mix tasks).

## Architecture

This is an **Elixir/Phoenix umbrella project** with four sub-applications sharing a single Phoenix endpoint:

### Apps

| App | Purpose | Repo |
|-----|---------|------|
| `hfg_portal` | Core: accounts, authorization, mailer | `HfgPortal.Repo` |
| `hfg_portal_web` | Phoenix web frontend, LiveView, controllers, router | — |
| `car_maintenance` | Car maintenance tracking | `CarMaintenance.Repo` |
| `loan_repayment` | Loan tracking | `LoanRepayment.Repo` |
| `wife_time` | Time tracking | `WifeTime.Repo` |

Each sub-app has its own Postgres database and Ecto repo. Migrations live in `apps/{app}/priv/repo/migrations/`.

### Authentication

Three separate auth systems, each with its own plug module in `hfg_portal_web/lib/hfg_portal_web/`:
- `user_auth.ex` — standard user sessions
- `customer_auth.ex` — customer sessions
- `api_user_auth.ex` — API token auth (JWT via `joken`/JOSE)

Google OAuth is also supported via `elixir_auth_google`.

### Frontend

- Phoenix LiveView 0.20.17 for real-time UI
- Tailwind CSS + esbuild for assets (configured in `config/config.exs`)
- Custom BNW-branded component library in `apps/hfg_portal_web/lib/hfg_portal_web/components/`
- LiveView modules in `apps/hfg_portal_web/lib/hfg_portal_web/live/`

### Config Layers

- `config/config.exs` — shared (esbuild, Tailwind, Phoenix, Google Auth)
- `config/dev.exs` — dev DB configs, file watchers
- `config/prod.exs` — production settings
- `config/runtime.exs` — env var binding (DB credentials, secrets, OAuth keys)
- `docker/development/.env` — Postgres (and legacy MySQL) credentials for Docker dev environment

### Key Runtime Dependencies

- PostgreSQL 16 (via `postgrex` driver)
- Email via Swoosh (local adapter in dev)
- Telemetry + LiveDashboard at `/dev/dashboard` (dev only)
- PubSub for real-time pub/sub across LiveViews
