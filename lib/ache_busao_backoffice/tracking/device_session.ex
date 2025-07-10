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
