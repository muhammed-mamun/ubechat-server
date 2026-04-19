defmodule Ubechat.Accounts do
  @moduledoc "Handles user registration, login, and profile management."

  import Ecto.Query, warn: false
  alias Ubechat.Repo
  alias Ubechat.Accounts.User

  # ---------------------------------------------------------------------------
  # Registration
  # ---------------------------------------------------------------------------

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------------

  @doc """
  Authenticates by email + password.
  Returns `{:ok, user}` or `{:error, :invalid_credentials}`.
  """
  def authenticate_user(email, password) do
    email = email |> String.downcase() |> String.trim()

    case Repo.get_by(User, email: email) do
      %User{password: hash} = user when not is_nil(hash) ->
        if Bcrypt.verify_pass(password, hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end

      _ ->
        # Constant-time compare to prevent timing attacks even when user doesn't exist
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  # ---------------------------------------------------------------------------
  # Queries
  # ---------------------------------------------------------------------------

  def get_user!(id), do: Repo.get!(User, id)
  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) do
    email = email |> String.downcase() |> String.trim()
    Repo.get_by(User, email: email)
  end

  # ---------------------------------------------------------------------------
  # Updates
  # ---------------------------------------------------------------------------

  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  def register_public_key(%User{} = user, public_key) do
    update_user(user, %{public_key: public_key})
  end

  def get_public_key(user_id) do
    case get_user(user_id) do
      %User{public_key: pk} when not is_nil(pk) -> {:ok, pk}
      %User{} -> {:error, :no_public_key}
      nil -> {:error, :not_found}
    end
  end
end
