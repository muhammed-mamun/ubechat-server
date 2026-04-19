defmodule Ubechat.Auth.Token do
  @moduledoc """
  JWT token generation and verification using Joken.

  Payload structure:
    %{
      "sub"  => user_id (UUID string),
      "iat"  => issued-at (unix timestamp),
      "exp"  => expiry   (unix timestamp)
    }
  """

  use Joken.Config

  # ---------------------------------------------------------------------------
  # Token generation
  # ---------------------------------------------------------------------------

  @doc """
  Generates a signed JWT for the given user_id.
  Returns `{:ok, token}` or `{:error, reason}`.
  """
  def generate(user_id) do
    ttl_seconds = ttl_hours() * 3_600
    now = :os.system_time(:second)

    claims = %{
      "sub" => user_id,
      "iat" => now,
      "exp" => now + ttl_seconds
    }

    signer = build_signer()

    case generate_and_sign(claims, signer) do
      {:ok, token, _claims} -> {:ok, token}
      {:error, reason} -> {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Token verification
  # ---------------------------------------------------------------------------

  @doc """
  Verifies a JWT token string.
  Returns `{:ok, claims}` or `{:error, reason}`.
  """
  def verify_token(token) do
    signer = build_signer()

    with {:ok, claims} <- verify_and_validate(token, signer) do
      check_expiry(claims)
    end
  end

  @doc """
  Extracts the user ID from a verified token (or raw Bearer header).
  Returns `{:ok, user_id}` or `{:error, reason}`.
  """
  def user_id_from_token(token) do
    with {:ok, claims} <- verify_token(token) do
      {:ok, claims["sub"]}
    end
  end


  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_signer do
    secret = Application.get_env(:ubechat, :jwt)[:secret] ||
      raise "JWT secret not configured"
    Joken.Signer.create("HS256", secret)
  end

  defp ttl_hours do
    Application.get_env(:ubechat, :jwt)[:ttl_hours] || 168
  end

  defp check_expiry(%{"exp" => exp} = claims) do
    now = :os.system_time(:second)

    if now < exp do
      {:ok, claims}
    else
      {:error, :token_expired}
    end
  end

  defp check_expiry(claims), do: {:ok, claims}
end
