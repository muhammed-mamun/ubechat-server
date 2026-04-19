# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ubechat,
  ecto_repos: [Ubechat.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

# Configure the endpoint
config :ubechat, UbechatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: UbechatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Ubechat.PubSub,
  live_view: [signing_salt: "tjGWiDV3"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :ubechat, Ubechat.Mailer, adapter: Swoosh.Adapters.Local

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Google Calendar Integration
config :ubechat, :google_oauth,
  client_id: System.get_env("GOOGLE_CLIENT_ID") || "REPLACE_ME_CLIENT_ID",
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET") || "REPLACE_ME_CLIENT_SECRET",
  redirect_uri:
    System.get_env("GOOGLE_REDIRECT_URI") || "exp://localhost:8081/--/api/calendar/callback"

# Machine Learning / Tensor Backend
config :nx, default_backend: EXLA.Backend

# Oban Background Jobs Core
config :ubechat, Oban,
  engine: Oban.Engines.Basic,
  queues: [calendar_sync: 10],
  repo: Ubechat.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
