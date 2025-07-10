# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     AcheBusaoBackoffice.Repo.insert!(%AcheBusaoBackoffice.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

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