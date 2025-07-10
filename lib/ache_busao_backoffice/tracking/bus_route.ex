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
