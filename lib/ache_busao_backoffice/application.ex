defmodule AcheBusaoBackoffice.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AcheBusaoBackofficeWeb.Telemetry,
      AcheBusaoBackoffice.Repo,
      {DNSCluster, query: Application.get_env(:ache_busao_backoffice, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AcheBusaoBackoffice.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: AcheBusaoBackoffice.Finch},
      # Start a worker by calling: AcheBusaoBackoffice.Worker.start_link(arg)
      # {AcheBusaoBackoffice.Worker, arg},
      # Start to serve requests, typically the last entry
      AcheBusaoBackofficeWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AcheBusaoBackoffice.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AcheBusaoBackofficeWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
