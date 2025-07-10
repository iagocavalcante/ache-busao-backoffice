defmodule AcheBusaoBackofficeWeb.Api.BusController do
  use AcheBusaoBackofficeWeb, :controller

  alias AcheBusaoBackoffice.Tracking
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
        {:ok, updated_session} = Tracking.end_device_session(session.id)

        duration = DateTime.diff(updated_session.ended_at, session.started_at, :millisecond)

        conn
        |> json(%{
          success: true,
          session_duration: duration
        })
    end
  end

  def positions(conn, params) do
    _timeout = String.to_integer(params["timeout"] || "30000")

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
