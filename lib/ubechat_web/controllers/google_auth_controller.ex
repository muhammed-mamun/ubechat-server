defmodule UbechatWeb.GoogleAuthController do
  use UbechatWeb, :controller

  alias Ubechat.Repo
  alias Ubechat.Accounts.Integration

  @google_auth_url "https://accounts.google.com/o/oauth2/v2/auth"
  @google_token_url "https://oauth2.googleapis.com/token"
  @scope "https://www.googleapis.com/auth/calendar.events"

  defp get_config do
    Application.get_env(:ubechat, :google_oauth, [])
  end

  @doc "Returns the frontend-friendly URL to redirect the user to Google."
  def auth_url(conn, _params) do
    config = get_config()
    client_id = Keyword.get(config, :client_id)
    redirect_uri = Keyword.get(config, :redirect_uri)

    query =
      URI.encode_query(%{
        "client_id" => client_id,
        "redirect_uri" => redirect_uri,
        "response_type" => "code",
        "scope" => @scope,
        "access_type" => "offline",
        "prompt" => "consent"
      })

    url = "#{@google_auth_url}?#{query}"
    json(conn, %{url: url})
  end

  @doc "Handles the OAuth redirect holding the authorization code."
  def callback(conn, %{"code" => code}) do
    # Assuming this endpoint is hit directly via Web and we use AuthPlug if it was an API.
    # But wait, Google overrides the Authorization Header on redirect, so usually we must
    # either pass the JWT in the URL state parameter OR let the frontend pass the code to us via a POST.

    # In API-only mode, it's MUCH safer for the frontend to handle the redirect webview natively,
    # capture the code, and POST it back to this `/api/calendar/callback?code=CODE` Endpoint with the Bearer Token.
    user = conn.assigns.current_user
    config = get_config()

    payload = %{
      "client_id" => Keyword.get(config, :client_id),
      "client_secret" => Keyword.get(config, :client_secret),
      "redirect_uri" => Keyword.get(config, :redirect_uri),
      "grant_type" => "authorization_code",
      "code" => code
    }

    case Req.post(@google_token_url, form: payload) do
      {:ok, %{status: 200, body: body}} ->
        access_token = body["access_token"]
        refresh_token = body["refresh_token"]
        expires_in = body["expires_in"] || 3600

        expires_at =
          DateTime.utc_now()
          |> DateTime.add(expires_in, :second)
          |> DateTime.truncate(:second)

        # Upsert integration
        integration_attrs = %{
          provider: "google",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          user_id: user.id
        }

        # If integration exists, update it. Otherwise insert.
        integration =
          Repo.get_by(Integration, user_id: user.id, provider: "google") || %Integration{}

        changeset = Integration.changeset(integration, integration_attrs)

        case Repo.insert_or_update(changeset) do
          {:ok, _} ->
            # Enqueue initial sync job
            %{user_id: user.id}
            |> Ubechat.Workers.CalendarSyncWorker.new()
            |> Oban.insert()

            json(conn, %{success: true, message: "Google Calendar linked successfully."})

          {:error, _} ->
            conn |> put_status(500) |> json(%{error: "Failed to save integration tokens."})
        end

      {:ok, %{body: err_body}} ->
        conn |> put_status(400) |> json(%{error: "Exchange failed", details: err_body})

      {:error, _} ->
        conn |> put_status(500) |> json(%{error: "Internal server error connecting to Google"})
    end
  end
end
