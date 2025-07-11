
defmodule AcheBusaoBackoffice.Tracking.LocationRetentionTest do
  use AcheBusaoBackoffice.DataCase

  alias AcheBusaoBackoffice.Tracking.LocationReport
  alias AcheBusaoBackoffice.Tracking.LocationRetention
  alias AcheBusaoBackoffice.Repo

  setup do
    # Ensure the GenServer is not running from previous tests
    if Process.whereis(LocationRetention), do: GenServer.stop(LocationRetention)

    # Start the GenServer for each test
    {:ok, pid} = GenServer.start_link(LocationRetention, %{}, name: LocationRetention)
    %{pid: pid}
  end

  test "starts and schedules cleanup", %{pid: pid} do
    assert Process.whereis(LocationRetention) == pid
    # We can't directly assert on scheduled messages without more complex mocking
    # but we can check if it's alive and registered.
  end

  test "deletes old location reports" do
    # Create a dummy BusRoute
    _bus_route =
      %AcheBusaoBackoffice.Tracking.BusRoute{
        route_id: "test_route_abc",
        name: "Test Route",
        color: "#FFFFFF",
        route_geometry: %Geo.LineString{coordinates: [{0.0, 0.0}, {1.0, 1.0}]}
      }
      |> Repo.insert!()

    # Create a dummy DeviceSession
    device_session =
      %AcheBusaoBackoffice.Tracking.DeviceSession{
        device_id: "test_device_123",
        route_id: "test_route_abc",
        device_info: %{"platform" => "test", "version" => "1.0"}
      }
      |> Repo.insert!()

    # Insert a recent report
    {:ok, _recent_report} =
      %LocationReport{
        device_session_id: device_session.id,
        location: %Geo.Point{coordinates: {1.0, 1.0}},
        accuracy: 5.0
      }
      |> Repo.insert()

    # Insert an old report (e.g., 25 hours ago)
    old_time = DateTime.utc_now() |> DateTime.add(-25 * 60 * 60 * 1000, :millisecond) |> DateTime.to_naive() |> NaiveDateTime.truncate(:second)
    {:ok, _old_report} =
      %LocationReport{
        device_session_id: device_session.id,
        location: %Geo.Point{coordinates: {2.0, 2.0}},
        accuracy: 5.0,
        inserted_at: old_time
      }
      |> Repo.insert()

    # Manually trigger cleanup (since we don't want to wait for the scheduled one)
    GenServer.call(LocationRetention, :cleanup)

    # Verify that only the old report was deleted
    recent_reports = Repo.all(from lr in LocationReport, where: lr.inserted_at > ^old_time)
    old_reports = Repo.all(from lr in LocationReport, where: lr.inserted_at < ^old_time)

    assert length(recent_reports) == 1
    assert length(old_reports) == 0
  end
end
