defmodule AcheBusaoBackoffice.Repo do
  use Ecto.Repo,
    otp_app: :ache_busao_backoffice,
    adapter: Ecto.Adapters.Postgres

  def init(_, opts) do
    opts = Keyword.put(opts, :types, AcheBusaoBackoffice.Repo.PostgresTypes)
    {:ok, opts}
  end
end

Postgrex.Types.define(
  AcheBusaoBackoffice.Repo.PostgresTypes,
  [Geo.PostGIS.Extension],
  json: Jason
)