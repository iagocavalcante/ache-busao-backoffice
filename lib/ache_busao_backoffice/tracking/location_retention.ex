
defmodule AcheBusaoBackoffice.Tracking.LocationRetention do
  use GenServer

  require Logger
  import Ecto.Query

  @retention_period_ms 24 * 60 * 60 * 1000 # 24 hours in milliseconds

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call(:cleanup, _from, state) do
    delete_old_location_reports()
    {:reply, :ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    delete_old_location_reports()
    {:noreply, state}
  end

  defp delete_old_location_reports() do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-@retention_period_ms, :millisecond)

    Logger.info("Deleting location reports older than \#{DateTime.to_iso8601(cutoff_time)}")

    case AcheBusaoBackoffice.Repo.delete_all(
           from(lr in AcheBusaoBackoffice.Tracking.LocationReport,
             where: lr.inserted_at < ^cutoff_time
           )
         ) do
      {_count, nil} ->
        Logger.info("Deleted \#{_count} old location reports.")

      {:error, _reason} ->
        Logger.error("Failed to delete old location reports: \#{inspect(_reason)}")
    end
  end
end
