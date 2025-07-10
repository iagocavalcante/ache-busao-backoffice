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
