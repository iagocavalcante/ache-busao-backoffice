defmodule AcheBusaoBackoffice.Repo.Migrations.EnablePostgis do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS postgis"
    execute "CREATE EXTENSION IF NOT EXISTS postgis_topology"
  end

  def down do
    execute "DROP EXTENSION IF EXISTS postgis_topology"
    execute "DROP EXTENSION IF EXISTS postgis"
  end
end