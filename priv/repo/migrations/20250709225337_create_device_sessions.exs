defmodule AcheBusaoBackoffice.Repo.Migrations.CreateDeviceSessions do
  use Ecto.Migration

  def change do
    create table(:device_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_id, :string, null: false
      add :device_info, :map
      add :route_id, :string, null: false
      add :is_active, :boolean, default: true
      add :started_at, :utc_datetime
      add :ended_at, :utc_datetime

      timestamps()
    end

    create index(:device_sessions, [:device_id])
    create index(:device_sessions, [:route_id])
    create index(:device_sessions, [:is_active])
  end
end