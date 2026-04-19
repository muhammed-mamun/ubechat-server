defmodule Ubechat.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  @doc """
  Adapts the existing Golang-created `users` table to the Phoenix schema.
  The table already exists; we only add missing columns.

  Existing columns: id, email, password, phone_number, display_name,
                    avatar_url, bio, is_online, last_seen, created_at,
                    updated_at, is_verified, otp_code, otp_expiry, public_key
  """
  def change do
    # The table already exists from the Golang backend, so we skip creation.
    # Indexes also exist on email and phone_number.
    # No additional columns are needed — we map directly to the existing schema.
    :ok
  end
end
