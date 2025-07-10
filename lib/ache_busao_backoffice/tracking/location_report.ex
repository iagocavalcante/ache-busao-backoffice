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
