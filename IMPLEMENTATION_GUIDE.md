# Implementation Guide - Getting Started

This guide provides step-by-step instructions to implement the bus tracking API based on the requirements outlined in `API_REQUIREMENTS.md`.

## Phase 1: Core Infrastructure Setup

### Step 1: Add Required Dependencies

Update your `mix.exs` file to include the necessary dependencies:

```elixir
defp deps do
  [
    # ... existing deps ...
    {:geo, "~> 3.4"},
    {:geo_postgis, "~> 3.4"},
    {:hammer, "~> 6.0"},
    {:phoenix_pubsub, "~> 2.0"},
    {:plug_crypto, "~> 1.2"},
    {:cachex, "~> 3.4"}
  ]
end
```

Run `mix deps.get` to install the new dependencies.

### Step 2: Configure PostGIS

Create a migration to enable PostGIS extension:

```bash
mix ecto.gen.migration enable_postgis
```

Edit the migration file:

```elixir
defmodule AcheBusaoBackoffice.Repo.Migrations.EnablePostgis do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS postgis"
    execute "CREATE EXTENSION IF NOT EXISTS postgis_topology"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS postgis_topology"
    execute "DROP EXTENSION IF EXISTS postgis"
  end
end
```

### Step 3: Create Database Schema

Generate migrations for the core tables:

```bash
mix ecto.gen.migration create_bus_routes
mix ecto.gen.migration create_device_sessions
mix ecto.gen.migration create_location_reports
mix ecto.gen.migration create_rate_limits
```

#### Bus Routes Migration

```elixir
defmodule AcheBusaoBackoffice.Repo.Migrations.CreateBusRoutes do
  use Ecto.Migration

  def change do
    create table(:bus_routes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :route_id, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :color, :string, null: false
      add :number, :string
      add :stops, {:array, :string}
      add :route_geometry, :geometry
      add :buffer_distance, :integer, default: 100
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:bus_routes, [:route_id])
    create index(:bus_routes, [:route_geometry], using: :gist)
  end
end
```

#### Device Sessions Migration

```elixir
defmodule AcheBusaoBackoffice.Repo.Migrations.CreateDeviceSessions do
  use Ecto.Migration

  def change do
    create table(:device_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_id, :string, null: false
      add :device_info, :map
      add :route_id, :string, null: false
      add :is_active, :boolean, default: true
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime

      timestamps()
    end

    create index(:device_sessions, [:device_id])
    create index(:device_sessions, [:route_id])
    create index(:device_sessions, [:is_active])
  end
end
```

#### Location Reports Migration

```elixir
defmodule AcheBusaoBackoffice.Repo.Migrations.CreateLocationReports do
  use Ecto.Migration

  def change do
    create table(:location_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :session_id, references(:device_sessions, type: :binary_id, on_delete: :delete_all)
      add :location, :geometry, null: false
      add :accuracy, :float
      add :timestamp, :utc_datetime
      add :is_valid, :boolean, default: true

      timestamps()
    end

    create index(:location_reports, [:session_id])
    create index(:location_reports, [:location], using: :gist)
    create index(:location_reports, [:timestamp])
  end
end
```

#### Rate Limits Migration

```elixir
defmodule AcheBusaoBackoffice.Repo.Migrations.CreateRateLimits do
  use Ecto.Migration

  def change do
    create table(:rate_limits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_id, :string, null: false
      add :endpoint, :string, null: false
      add :request_count, :integer, default: 1
      add :window_start, :utc_datetime

      timestamps()
    end

    create unique_index(:rate_limits, [:device_id, :endpoint, :window_start])
  end
end
```

### Step 4: Create Ecto Schemas

#### Bus Route Schema

Create `lib/ache_busao_backoffice/tracking/bus_route.ex`:

```elixir
defmodule AcheBusaoBackoffice.Tracking.BusRoute do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bus_routes" do
    field :route_id, :string
    field :name, :string
    field :description, :string
    field :color, :string
    field :number, :string
    field :stops, {:array, :string}
    field :route_geometry, Geo.PostGIS.Geometry
    field :buffer_distance, :integer, default: 100
    field :is_active, :boolean, default: true

    has_many :device_sessions, AcheBusaoBackoffice.Tracking.DeviceSession,
             foreign_key: :route_id, references: :route_id

    timestamps()
  end

  @doc false
  def changeset(bus_route, attrs) do
    bus_route
    |> cast(attrs, [:route_id, :name, :description, :color, :number, :stops,
                    :route_geometry, :buffer_distance, :is_active])
    |> validate_required([:route_id, :name, :color])
    |> unique_constraint(:route_id)
    |> validate_format(:color, ~r/^#[0-9A-Fa-f]{6}$/)
  end
end
```

#### Device Session Schema

Create `lib/ache_busao_backoffice/tracking/device_session.ex`:

```elixir
defmodule AcheBusaoBackoffice.Tracking.DeviceSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "device_sessions" do
    field :device_id, :string
    field :device_info, :map
    field :route_id, :string
    field :is_active, :boolean, default: true
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime

    belongs_to :bus_route, AcheBusaoBackoffice.Tracking.BusRoute,
               foreign_key: :route_id, references: :route_id, define_field: false
    has_many :location_reports, AcheBusaoBackoffice.Tracking.LocationReport

    timestamps()
  end

  @doc false
  def changeset(device_session, attrs) do
    device_session
    |> cast(attrs, [:device_id, :device_info, :route_id, :is_active, :started_at, :ended_at])
    |> validate_required([:device_id, :route_id])
    |> put_started_at()
  end

  defp put_started_at(changeset) do
    case get_field(changeset, :started_at) do
      nil -> put_change(changeset, :started_at, DateTime.utc_now())
      _ -> changeset
    end
  end
end
```

#### Location Report Schema

Create `lib/ache_busao_backoffice/tracking/location_report.ex`:

```elixir
defmodule AcheBusaoBackoffice.Tracking.LocationReport do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "location_reports" do
    field :location, Geo.PostGIS.Geometry
    field :accuracy, :float
    field :timestamp, :utc_datetime
    field :is_valid, :boolean, default: true

    belongs_to :device_session, AcheBusaoBackoffice.Tracking.DeviceSession

    timestamps()
  end

  @doc false
  def changeset(location_report, attrs) do
    location_report
    |> cast(attrs, [:location, :accuracy, :timestamp, :is_valid, :session_id])
    |> validate_required([:location, :session_id])
    |> put_timestamp()
  end

  defp put_timestamp(changeset) do
    case get_field(changeset, :timestamp) do
      nil -> put_change(changeset, :timestamp, DateTime.utc_now())
      _ -> changeset
    end
  end
end
```

### Step 5: Create Context Module

Create `lib/ache_busao_backoffice/tracking.ex`:

```elixir
defmodule AcheBusaoBackoffice.Tracking do
  @moduledoc """
  The Tracking context.
  """

  import Ecto.Query, warn: false
  alias AcheBusaoBackoffice.Repo

  alias AcheBusaoBackoffice.Tracking.{BusRoute, DeviceSession, LocationReport}

  @doc """
  Returns the list of bus routes.
  """
  def list_bus_routes do
    Repo.all(BusRoute)
  end

  @doc """
  Gets a single bus route.
  """
  def get_bus_route!(id), do: Repo.get!(BusRoute, id)

  @doc """
  Gets a bus route by route_id.
  """
  def get_bus_route_by_route_id(route_id) do
    Repo.get_by(BusRoute, route_id: route_id)
  end

  @doc """
  Creates a bus route.
  """
  def create_bus_route(attrs \\ %{}) do
    %BusRoute{}
    |> BusRoute.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Starts a new device session.
  """
  def start_device_session(attrs \\ %{}) do
    %DeviceSession{}
    |> DeviceSession.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Ends a device session.
  """
  def end_device_session(session_id) do
    session = Repo.get!(DeviceSession, session_id)

    session
    |> DeviceSession.changeset(%{is_active: false, ended_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Gets an active device session.
  """
  def get_active_session(session_id) do
    DeviceSession
    |> where([s], s.id == ^session_id and s.is_active == true)
    |> Repo.one()
  end

  @doc """
  Creates a location report.
  """
  def create_location_report(attrs \\ %{}) do
    %LocationReport{}
    |> LocationReport.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Validates if a location is within a route's buffer zone.
  """
  def validate_location_within_route(route_id, longitude, latitude) do
    query = """
    SELECT EXISTS(
      SELECT 1 FROM bus_routes
      WHERE route_id = $1
      AND ST_DWithin(
        route_geometry,
        ST_SetSRID(ST_MakePoint($2, $3), 4326)::geography,
        buffer_distance
      )
    )
    """

    case Repo.query(query, [route_id, longitude, latitude]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  @doc """
  Gets the latest location for each active route.
  """
  def get_latest_route_positions do
    query = """
    SELECT DISTINCT ON (br.route_id)
      br.route_id,
      br.name,
      br.color,
      br.stops,
      ST_X(lr.location) as longitude,
      ST_Y(lr.location) as latitude,
      lr.timestamp,
      COUNT(ds.id) OVER (PARTITION BY br.route_id) as active_users
    FROM bus_routes br
    JOIN device_sessions ds ON br.route_id = ds.route_id
    JOIN location_reports lr ON ds.id = lr.session_id
    WHERE ds.is_active = true
    AND lr.is_valid = true
    AND lr.timestamp > NOW() - INTERVAL '1 hour'
    ORDER BY br.route_id, lr.timestamp DESC
    """

    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [route_id, name, color, stops, lng, lat, timestamp, active_users] ->
          %{
            route_id: route_id,
            name: name,
            color: color,
            stops: stops,
            last_position: %{
              longitude: lng,
              latitude: lat,
              updated_at: timestamp
            },
            active_users: active_users
          }
        end)
      _ -> []
    end
  end
end
```

### Step 6: Create API Controllers

Create `lib/ache_busao_backoffice_web/controllers/api/bus_controller.ex`:

```elixir
defmodule AcheBusaoBackofficeWeb.Api.BusController do
  use AcheBusaoBackofficeWeb, :controller

  alias AcheBusaoBackoffice.Tracking
  alias AcheBusaoBackoffice.Tracking.LocationReport

  action_fallback AcheBusaoBackofficeWeb.FallbackController

  def start_session(conn, %{"route_id" => route_id, "device_info" => device_info, "initial_location" => location}) do
    device_id = generate_device_id(device_info)

    # Validate initial location
    is_valid = Tracking.validate_location_within_route(
      route_id,
      location["longitude"],
      location["latitude"]
    )

    unless is_valid do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "Initial location is not within route bounds"})
    else
      case Tracking.start_device_session(%{
        device_id: device_id,
        device_info: device_info,
        route_id: route_id
      }) do
        {:ok, session} ->
          # Create initial location report
          point = %Geo.Point{coordinates: {location["longitude"], location["latitude"]}}

          Tracking.create_location_report(%{
            session_id: session.id,
            location: point,
            accuracy: location["accuracy"],
            is_valid: true
          })

          route = Tracking.get_bus_route_by_route_id(route_id)

          conn
          |> put_status(:created)
          |> json(%{
            session_id: session.id,
            route_info: %{
              id: route.route_id,
              name: route.name,
              color: route.color
            },
            update_interval: 60000,
            success: true
          })

        {:error, _changeset} ->
          conn
          |> put_status(:bad_request)
          |> json(%{error: "Failed to start session"})
      end
    end
  end

  def update_location(conn, %{"session_id" => session_id, "location" => location}) do
    case Tracking.get_active_session(session_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found or inactive"})

      session ->
        # Validate location
        is_valid = Tracking.validate_location_within_route(
          session.route_id,
          location["longitude"],
          location["latitude"]
        )

        point = %Geo.Point{coordinates: {location["longitude"], location["latitude"]}}

        case Tracking.create_location_report(%{
          session_id: session.id,
          location: point,
          accuracy: location["accuracy"],
          is_valid: is_valid
        }) do
          {:ok, _report} ->
            conn
            |> json(%{
              success: true,
              is_valid_location: is_valid,
              next_update_in: 60000
            })

          {:error, _changeset} ->
            conn
            |> put_status(:bad_request)
            |> json(%{error: "Failed to update location"})
        end
    end
  end

  def end_session(conn, %{"session_id" => session_id}) do
    case Tracking.get_active_session(session_id) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Session not found or inactive"})

      session ->
        {:ok, updated_session} = Tracking.end_device_session(session_id)

        duration = DateTime.diff(updated_session.ended_at, session.started_at, :millisecond)

        conn
        |> json(%{
          success: true,
          session_duration: duration
        })
    end
  end

  def positions(conn, params) do
    timeout = String.to_integer(params["timeout"] || "30000")

    positions = Tracking.get_latest_route_positions()

    conn
    |> json(%{
      routes: positions,
      timestamp: DateTime.utc_now()
    })
  end

  defp generate_device_id(device_info) do
    # Simple device ID generation - in production, use more sophisticated fingerprinting
    content = "#{device_info["platform"]}-#{device_info["device_model"]}-#{device_info["app_version"]}"
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
```

### Step 7: Create Route Controller

Create `lib/ache_busao_backoffice_web/controllers/api/route_controller.ex`:

```elixir
defmodule AcheBusaoBackofficeWeb.Api.RouteController do
  use AcheBusaoBackofficeWeb, :controller

  alias AcheBusaoBackoffice.Tracking

  def index(conn, _params) do
    routes = Tracking.list_bus_routes()

    formatted_routes = Enum.map(routes, fn route ->
      %{
        route_id: route.route_id,
        name: route.name,
        description: route.description,
        color: route.color,
        number: route.number,
        stops: route.stops || [],
        active_users: get_active_users_count(route.route_id)
      }
    end)

    conn
    |> json(%{routes: formatted_routes})
  end

  defp get_active_users_count(route_id) do
    # This would be optimized with a proper query
    # For now, return a placeholder
    0
  end
end
```

### Step 8: Add API Routes

Update `lib/ache_busao_backoffice_web/router.ex`:

```elixir
defmodule AcheBusaoBackofficeWeb.Router do
  use AcheBusaoBackofficeWeb, :router

  # ... existing code ...

  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
  end

  # ... existing routes ...

  scope "/api/v1", AcheBusaoBackofficeWeb.Api, as: :api do
    pipe_through :api

    resources "/routes", RouteController, only: [:index]

    scope "/bus" do
      post "/start-session", BusController, :start_session
      put "/update-location/:session_id", BusController, :update_location
      delete "/end-session/:session_id", BusController, :end_session
      get "/positions", BusController, :positions
    end
  end
end
```

### Step 9: Seed Initial Data

Update `priv/repo/seeds.exs` to include the mock bus routes:

```elixir
# Bus routes from mock data
alias AcheBusaoBackoffice.Tracking

mock_routes = [
  %{
    route_id: "belem-113",
    name: "113 Cremação / Estrada Nova",
    description: "Cremação / Estrada Nova",
    color: "#FF6B6B",
    number: "113",
    stops: ["Cremação", "Estrada Nova"]
  },
  %{
    route_id: "belem-114",
    name: "114 Cremação / Alcindo Cacela",
    description: "Cremação / Alcindo Cacela",
    color: "#4ECDC4",
    number: "114",
    stops: ["Cremação", "Alcindo Cacela"]
  },
  %{
    route_id: "belem-305",
    name: "305 UFPA / Icoaraci",
    description: "UFPA / Icoaraci",
    color: "#85C1E9",
    number: "305",
    stops: ["UFPA", "Campus UFPA", "Reitoria", "Hospital Universitário", "Icoaraci"]
  }
  # Add more routes as needed
]

Enum.each(mock_routes, fn route_data ->
  case Tracking.get_bus_route_by_route_id(route_data.route_id) do
    nil -> Tracking.create_bus_route(route_data)
    _existing -> :ok
  end
end)
```

### Step 10: Run Migrations and Setup

```bash
mix ecto.migrate
mix run priv/repo/seeds.exs
```

### Step 11: Test the API

Start the server:
```bash
mix phx.server
```

Test the endpoints:

```bash
# Get routes
curl -X GET http://localhost:4000/api/v1/routes

# Start a session
curl -X POST http://localhost:4000/api/v1/bus/start-session \
  -H "Content-Type: application/json" \
  -d '{
    "route_id": "belem-305",
    "device_info": {
      "platform": "ios",
      "version": "17.0",
      "app_version": "1.0.0",
      "device_model": "iPhone 14"
    },
    "initial_location": {
      "latitude": -1.4789,
      "longitude": -48.3789,
      "accuracy": 10.0
    }
  }'

# Get bus positions
curl -X GET http://localhost:4000/api/v1/bus/positions
```

## Next Steps

1. **Add Rate Limiting**: Implement rate limiting middleware using Hammer
2. **Improve Location Validation**: Add actual route geometry data
3. **Add Long Polling**: Implement proper long polling for real-time updates
4. **Add Error Handling**: Implement comprehensive error handling
5. **Add Tests**: Create comprehensive test suite
6. **Add Monitoring**: Implement logging and monitoring

This implementation provides a solid foundation for your bus tracking API. You can build upon this by adding the remaining features outlined in the requirements document.
