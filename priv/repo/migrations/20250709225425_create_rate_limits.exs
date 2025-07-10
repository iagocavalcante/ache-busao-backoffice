defmodule AcheBusaoBackoffice.Repo.Migrations.CreateRateLimits do
  use Ecto.Migration

  def change do
    create table(:rate_limits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :device_id, :string, null: false
      add :endpoint, :string, null: false
      add :request_count, :integer, default: 1
      add :window_start, :utc_datetime

      timestamps()
    end

    create unique_index(:rate_limits, [:device_id, :endpoint, :window_start])
  end
end