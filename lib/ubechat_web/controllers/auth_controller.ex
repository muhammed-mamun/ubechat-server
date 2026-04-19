defmodule UbechatWeb.AuthController do
  use UbechatWeb, :controller

  alias Ubechat.Accounts
  alias Ubechat.Auth.Token

  # ---------------------------------------------------------------------------
  # POST /api/auth/register
  # ---------------------------------------------------------------------------

  @doc """
  Registers a new user.

  Body: { "display_name", "email", "password", "phone"?, "public_key"? }
  """
  def register(conn, params) do
    attrs = %{
      display_name: params["display_name"],
      email: params["email"],
      plain_password: params["password"],
      phone_number: params["phone"],
      public_key: params["public_key"]
    }

    case Accounts.register_user(attrs) do
      {:ok, user} ->
        {:ok, token} = Token.generate(user.id)

        conn
        |> put_status(:created)
        |> json(%{
          token: token,
          user: user_json(user)
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/auth/login
  # ---------------------------------------------------------------------------

  @doc """
  Authenticates a user by email + password, returns a JWT.

  Body: { "email", "password" }
  """
  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, token} = Token.generate(user.id)

        conn
        |> put_status(:ok)
        |> json(%{
          token: token,
          user: user_json(user)
        })

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "email and password are required"})
  end

  # ---------------------------------------------------------------------------
  # GET /api/auth/me   (requires AuthPlug)
  # ---------------------------------------------------------------------------

  @doc "Returns the current authenticated user's profile."
  def me(conn, _params) do
    user = conn.assigns.current_user
    json(conn, %{user: user_json(user)})
  end

  # ---------------------------------------------------------------------------
  # PUT /api/auth/me   (requires AuthPlug)
  # ---------------------------------------------------------------------------

  @doc "Updates display_name, phone, avatar_url."
  def update_me(conn, params) do
    user = conn.assigns.current_user
    attrs = Map.take(params, ["display_name", "phone", "avatar_url"])

    case Accounts.update_user(user, attrs) do
      {:ok, updated_user} ->
        json(conn, %{user: user_json(updated_user)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  # ---------------------------------------------------------------------------
  # PUT /api/auth/public_key   (requires AuthPlug)
  # ---------------------------------------------------------------------------

  @doc "Registers or updates the user's E2EE public key."
  def register_public_key(conn, %{"public_key" => public_key}) do
    user = conn.assigns.current_user

    case Accounts.register_public_key(user, public_key) do
      {:ok, updated_user} ->
        json(conn, %{user: user_json(updated_user)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def register_public_key(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "public_key is required"})
  end

  # ---------------------------------------------------------------------------
  # GET /api/users/:id/public_key   (requires AuthPlug)
  # ---------------------------------------------------------------------------

  @doc "Retrieves another user's E2EE public key for client-side encryption."
  def get_public_key(conn, %{"id" => user_id}) do
    case Accounts.get_public_key(user_id) do
      {:ok, public_key} ->
        json(conn, %{user_id: user_id, public_key: public_key})

      {:error, :no_public_key} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User has no registered public key"})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp user_json(user) do
    %{
      id: user.id,
      display_name: user.display_name,
      email: user.email,
      phone: user.phone_number,
      avatar_url: user.avatar_url,
      has_public_key: not is_nil(user.public_key),
      inserted_at: user.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
