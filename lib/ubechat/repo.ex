defmodule Ubechat.Repo do
  use Ecto.Repo,
    otp_app: :ubechat,
    adapter: Ecto.Adapters.Postgres
end
