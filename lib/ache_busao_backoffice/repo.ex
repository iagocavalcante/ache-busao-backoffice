defmodule AcheBusaoBackoffice.Repo do
  use Ecto.Repo,
    otp_app: :ache_busao_backoffice,
    adapter: Ecto.Adapters.Postgres
end