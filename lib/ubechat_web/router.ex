defmodule UbechatWeb.Router do
  use UbechatWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :auth do
    plug :accepts, ["json"]
    plug UbechatWeb.AuthPlug
  end

  # ---------------------------------------------------------------------------
  # Public routes — no token required
  # ---------------------------------------------------------------------------
  scope "/api", UbechatWeb do
    pipe_through :api

    post "/auth/register", AuthController, :register
    post "/auth/login", AuthController, :login
  end

  # ---------------------------------------------------------------------------
  # Protected routes — valid JWT required (AuthPlug)
  # ---------------------------------------------------------------------------
  scope "/api", UbechatWeb do
    pipe_through :auth

    get "/auth/me", AuthController, :me
    put "/auth/me", AuthController, :update_me
    put "/auth/public_key", AuthController, :register_public_key
    get "/users/:id/public_key", AuthController, :get_public_key

    get "/users", UserController, :index
  end


  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ubechat, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: UbechatWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
