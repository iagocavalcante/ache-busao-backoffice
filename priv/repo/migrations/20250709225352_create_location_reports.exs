defmodule AcheBusaoBackoffice.Repo.Migrations.CreateLocationReports do
  use Ecto.Migration

  def change do
    create table(:location_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_session_id, references(:device_sessions, type: :binary_id, on_delete: :delete_all)
      add :location, :geometry, null: false
      add :accuracy, :float
      add :timestamp, :utc_datetime
      add :is_valid, :boolean, default: true

      timestamps()
    end

    create index(:location_reports, [:device_session_id])
    create index(:location_reports, [:location], using: :gist)
    create index(:location_reports, [:timestamp])
  end
end