defmodule Ubechat.Calendar do
  @moduledoc "Context for fetching and managing Google Calendar events using stored Integration tokens."

  alias Ubechat.Repo
  alias Ubechat.Accounts.Integration
  import Ecto.Query

  @google_cal_url "https://www.googleapis.com/calendar/v3/calendars/primary/events"
  @google_token_url "https://oauth2.googleapis.com/token"

  def list_upcoming_events(user_id) do
    case get_integration(user_id) do
      nil ->
        {:error, :not_connected}

      %Integration{} = integration ->
        # We should refresh token if expired, but for MVP we assume it's valid 
        # or we refresh it opportunistically.
        fetch_events_from_google(integration)
    end
  end

  def create_event(user_id, event_params) do
    # event_params should have %{"summary" => "...", "start" => %{...}, "end" => %{...}}
    case get_integration(user_id) do
      nil -> {:error, :not_connected}
      %Integration{} = integration ->
        post_event_to_google(integration, event_params)
    end
  end

  defp get_integration(user_id) do
    Repo.one(from i in Integration, where: i.user_id == ^user_id and i.provider == "google")
  end

  defp fetch_events_from_google(integration) do
    # Using the access token to fetch up to 10 incoming events
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    url = "#{@google_cal_url}?timeMin=#{now}&maxResults=10&singleEvents=true&orderBy=startTime"

    Req.get(url, auth: {:bearer, integration.access_token})
    |> handle_google_response(integration)
  end

  defp post_event_to_google(integration, payload) do
    Req.post(@google_cal_url, json: payload, auth: {:bearer, integration.access_token})
    |> handle_google_response(integration)
  end

  defp handle_google_response(result, integration) do
    case result do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        # Token expired, need to use refresh_token
        refresh_access_token(integration)

      {:ok, %{status: status, body: body}} ->
        {:error, %{status: status, details: body}}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp refresh_access_token(integration) do
    if is_nil(integration.refresh_token) do
      {:error, :auth_expired}
    else
      config = Application.get_env(:ubechat, :google_oauth, [])
      
      payload = %{
        "client_id" => Keyword.get(config, :client_id),
        "client_secret" => Keyword.get(config, :client_secret),
        "grant_type" => "refresh_token",
        "refresh_token" => integration.refresh_token
      }

      case Req.post(@google_token_url, form: payload) do
        {:ok, %{status: 200, body: body}} ->
          # Update integration with new access token
          expires_in = body["expires_in"] || 3600
          expires_at = DateTime.add(DateTime.utc_now(), expires_in, :second) |> DateTime.truncate(:second)

          new_attrs = %{access_token: body["access_token"], expires_at: expires_at}
          changeset = Integration.changeset(integration, new_attrs)
          Repo.update!(changeset)

          {:error, :token_refreshed_retry} # A signal to the caller to retry

        _ ->
          {:error, :refresh_failed}
      end
    end
  end
end
