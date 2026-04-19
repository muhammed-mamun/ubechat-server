defmodule UbechatWeb.CalendarController do
  use UbechatWeb, :controller

  alias Ubechat.Calendar

  @doc "Fetches this user's upcoming 10 events."
  def list_events(conn, _params) do
    user = conn.assigns.current_user

    case Calendar.list_upcoming_events(user.id) do
      {:ok, body} ->
        json(conn, %{events: body["items"] || []})

      {:error, :not_connected} ->
        conn |> put_status(403) |> json(%{error: "Google Calendar not connected"})

      {:error, :token_refreshed_retry} ->
        # Quick retry logic if token was transparently refreshed
        case Calendar.list_upcoming_events(user.id) do
          {:ok, body} ->
            json(conn, %{events: body["items"] || []})

          {:error, _} ->
            conn |> put_status(500) |> json(%{error: "Error processing refreshed token"})
        end

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: inspect(reason)})
    end
  end

  @doc "Creates a new event on this user's calendar."
  def create_event(conn, params) do
    user = conn.assigns.current_user

    # params should ideally pass "summary", "start", "end"
    payload = Map.take(params, ["summary", "description", "start", "end", "attendees"])

    case Calendar.create_event(user.id, payload) do
      {:ok, body} ->
        json(conn, body)

      {:error, :not_connected} ->
        conn |> put_status(403) |> json(%{error: "Google Calendar not connected"})

      {:error, :token_refreshed_retry} ->
        case Calendar.create_event(user.id, payload) do
          {:ok, body} ->
            json(conn, body)

          {:error, _} ->
            conn |> put_status(500) |> json(%{error: "Error processing refreshed token"})
        end

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: inspect(reason)})
    end
  end

  def sync_now(conn, _params) do
    user = conn.assigns.current_user

    %{user_id: user.id}
    |> Ubechat.Workers.CalendarSyncWorker.new()
    |> Oban.insert()

    json(conn, %{success: true, message: "Sync job enqueued."})
  end
end
