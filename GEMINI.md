# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "Ache o Busão Backoffice" - a Phoenix/Elixir web application for managing bus route information. It's a standard Phoenix 1.7+ application with LiveView, Ecto, and PostgreSQL.

## Development Commands

### Setup and Dependencies
- `mix setup` - Install dependencies and setup database (runs deps.get, ecto.setup, assets.setup, assets.build)
- `mix deps.get` - Install Elixir dependencies only

### Server Management
- `mix phx.server` - Start the Phoenix server (accessible at http://localhost:4000)
- `iex -S mix phx.server` - Start server in interactive Elixir shell

### Database Operations
- `mix ecto.create` - Create database
- `mix ecto.migrate` - Run pending migrations
- `mix ecto.setup` - Create database, run migrations, and seed data
- `mix ecto.reset` - Drop database and recreate (runs ecto.drop then ecto.setup)

### Testing
- `mix test` - Run all tests (automatically sets up test database)

### Assets
- `mix assets.setup` - Install asset dependencies (Tailwind CSS and esbuild)
- `mix assets.build` - Build assets for development
- `mix assets.deploy` - Build and minify assets for production

## Architecture

### Application Structure
- **Main Application**: `AcheBusaoBackoffice.Application` - OTP application supervisor
- **Web Layer**: `AcheBusaoBackofficeWeb` - Phoenix web interface
- **Database**: Uses Ecto with PostgreSQL via `AcheBusaoBackoffice.Repo`
- **Styling**: Tailwind CSS with esbuild for asset compilation

### Key Components
- **Router**: `AcheBusaoBackofficeWeb.Router` - defines routes with browser and API pipelines
- **Endpoint**: `AcheBusaoBackofficeWeb.Endpoint` - Phoenix endpoint with LiveView socket support
- **Controllers**: Located in `lib/ache_busao_backoffice_web/controllers/`
- **LiveView Components**: Core components in `lib/ache_busao_backoffice_web/components/`
- **Layouts**: HEEx templates in `lib/ache_busao_backoffice_web/components/layouts/`

### Database
- Migrations: `priv/repo/migrations/`
- Seeds: `priv/repo/seeds.exs`
- Models: `lib/ache_busao_backoffice/` (following Phoenix 1.7+ context pattern)

### Development Tools
- **LiveDashboard**: Available at `/dev/dashboard` in development
- **Mailbox Preview**: Available at `/dev/mailbox` in development (Swoosh)
- **Live Reload**: Automatic browser refresh in development
- **Telemetry**: Built-in metrics and monitoring

### Configuration
- Environment configs in `config/` directory
- `config.exs` - base configuration
- `dev.exs` - development environment
- `prod.exs` - production environment
- `test.exs` - test environment
- `runtime.exs` - runtime configuration

## Testing
Tests are located in `test/` directory with:
- `test/support/conn_case.ex` - Controller test helpers
- `test/support/data_case.ex` - Database test helpers
- `test/test_helper.exs` - Test configuration

The test environment automatically creates and migrates a test database before running tests.