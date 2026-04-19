defmodule Ubechat.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @moduledoc """
  Maps to the existing `users` table created by the Golang backend.

  Column mapping:
    - id            → integer (sequence) — kept for backward compat
    - email         → varchar(255)  UNIQUE NOT NULL
    - password      → varchar(255)  stores the bcrypt hash
    - phone_number  → varchar(50)
    - display_name  → varchar(100)
    - avatar_url    → text
    - public_key    → text
    - created_at    → timestamptz
    - updated_at    → timestamptz
  """

  schema "users" do
    field :email, :string
    field :password, :string          # the bcrypt hash stored in the DB
    field :phone_number, :string
    field :display_name, :string
    field :avatar_url, :string
    field :bio, :string
    field :public_key, :string
    field :is_online, :boolean, default: false
    field :is_verified, :boolean, default: false
    field :last_seen, :utc_datetime

    # Virtual — not persisted, used only for input validation
    field :plain_password, :string, virtual: true

    field :inserted_at, :utc_datetime, source: :created_at, read_after_writes: true
    field :updated_at, :utc_datetime, source: :updated_at, read_after_writes: true

    has_many :integrations, Ubechat.Accounts.Integration
  end

  # ---------------------------------------------------------------------------
  # Changesets
  # ---------------------------------------------------------------------------


  @doc "Registration changeset."
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :plain_password, :display_name, :phone_number, :avatar_url])
    |> validate_required([:email, :plain_password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    |> validate_length(:plain_password, min: 8, max: 128)
    |> validate_length(:display_name, max: 100)
    |> normalize_email()
    |> unique_constraint(:email)
    |> unique_constraint(:phone_number)
    |> put_password_hash()
  end

  @doc "Update profile changeset (no password change)."
  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :phone_number, :avatar_url, :bio, :public_key])
    |> validate_length(:display_name, max: 100)
    |> unique_constraint(:phone_number)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp normalize_email(changeset) do
    update_change(changeset, :email, fn e -> e |> String.downcase() |> String.trim() end)
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{plain_password: pwd}} ->
        put_change(changeset, :password, Bcrypt.hash_pwd_salt(pwd))

      _ ->
        changeset
    end
  end
end
