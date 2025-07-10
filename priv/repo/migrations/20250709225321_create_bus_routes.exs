defmodule AcheBusaoBackoffice.Repo.Migrations.CreateBusRoutes do
  use Ecto.Migration

  def change do
    create table(:bus_routes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :route_id, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :color, :string, null: false
      add :number, :string
      add :stops, {:array, :string}
      add :route_geometry, :geometry
      add :buffer_distance, :integer, default: 100
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:bus_routes, [:route_id])
    create index(:bus_routes, [:route_geometry], using: :gist)
  end
end