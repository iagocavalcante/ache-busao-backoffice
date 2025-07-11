defmodule AcheBusaoBackofficeWeb.Router do
  use AcheBusaoBackofficeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AcheBusaoBackofficeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
  end

  pipeline :api_rate_limited do
    plug :accepts, ["json"]
    plug :put_secure_browser_headers
    plug AcheBusaoBackofficeWeb.Plugs.RateLimiter, endpoint: "update_location", max_requests: 10, window_ms: 60_000
  end

  scope "/", AcheBusaoBackofficeWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", AcheBusaoBackofficeWeb do
  #   pipe_through :api
  # end

  scope "/api/v1", AcheBusaoBackofficeWeb.Api, as: :api do
    pipe_through :api

    resources "/routes", RouteController, only: [:index]

    scope "/bus" do
      post "/start-session", BusController, :start_session
      delete "/end-session/:session_id", BusController, :end_session
      get "/positions", BusController, :positions

      scope "/", as: :bus do
        pipe_through :api_rate_limited
        put "/update-location/:session_id", BusController, :update_location
      end
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ache_busao_backoffice, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AcheBusaoBackofficeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
