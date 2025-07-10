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

  defp get_active_users_count(_route_id) do
    # This would be optimized with a proper query
    # For now, return a placeholder
    0
  end
end
