
defmodule AcheBusaoBackofficeWeb.Plugs.RateLimiter do
  import Plug.Conn
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, opts) do
    # Get device_id from params or headers, depending on how it's sent
    # For now, let's assume it's in the JSON body for update_location
    # In a real app, you'd likely get it from a session or a dedicated header
    device_id = get_device_id(conn)
    endpoint = opts[:endpoint] || "default"
    max_requests = opts[:max_requests] || 10
    window_ms = opts[:window_ms] || 60_000 # 1 minute

    case Hammer.check_rate("rate_limit:#{device_id}:#{endpoint}", window_ms, max_requests) do
      {:allow, _count} ->
        conn

      {:deny, _count} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(trunc(window_ms / 1000)))
        |> send_resp(429, "Too Many Requests")
        |> halt()
    end
  end

  defp get_device_id(conn) do
    # This is a placeholder. In a real application, device_id would be
    # extracted securely and reliably, e.g., from a validated session,
    # a unique device fingerprint generated on start_session, or a custom header.
    # For this exercise, we'll try to get it from the JSON body if available.
    case Plug.Conn.read_body(conn) do
      {:ok, body, _conn} ->
        case Jason.decode(body) do
          {:ok, %{"device_id" => device_id}} ->
            device_id
          _ ->
            # Fallback if device_id not in body or body not JSON
            "unknown_device"
        end
      _ ->
        "unknown_device"
    end
  end
end
