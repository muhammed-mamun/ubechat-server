defmodule Ubechat.Workers.CalendarSyncWorker do
  @moduledoc """
  Background worker executing safely decoupled from web requests.
  Queries Google Calendar, maps the data, generates a real-time semantic embedding using ONNX,
  and natively performs a relational Ecto Upsert to Pgvector structures.
  """
  use Oban.Worker, queue: :calendar_sync
  alias Ubechat.Repo
  alias Ubechat.Calendar.Event

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    case Ubechat.Calendar.list_upcoming_events(user_id) do
      {:ok, body} ->
        events = body["items"] || []

        for item <- events do
          google_event_id = item["id"]
          summary = item["summary"] || ""
          description = item["description"] || ""

          # Map time gracefully handling all-day dates and missing offset types
          start_time = get_time(item["start"])
          end_time = get_time(item["end"])

          # Inject semantic map parsing via EXLA
          # Fusing summary and description text together enriches RAG querying
          text_to_embed = "#{summary}. #{description}"
          embedding = Ubechat.Embeddings.generate(text_to_embed)

          attrs = %{
            user_id: user_id,
            google_event_id: google_event_id,
            summary: summary,
            description: description,
            start_time: start_time,
            end_time: end_time,
            embedding: embedding
          }

          # Conflict Upsert Strategy
          existing_event = Repo.get_by(Event, user_id: user_id, google_event_id: google_event_id)

          if existing_event do
            Event.changeset(existing_event, attrs) |> Repo.update!()
          else
            %Event{} |> Event.changeset(attrs) |> Repo.insert!()
          end

          # Push to Graph for AI
          Ubechat.Graph.log_calendar_event(
            user_id,
            google_event_id,
            summary,
            start_time,
            end_time
          )
        end

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_time(%{"dateTime" => dt}), do: parse_date(dt)
  defp get_time(%{"date" => d}), do: parse_date("#{d}T00:00:00Z")
  defp get_time(_), do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp parse_date(dt_str) do
    case DateTime.from_iso8601(dt_str) do
      {:ok, dt, _offset} -> DateTime.truncate(dt, :second)
      _ -> DateTime.utc_now() |> DateTime.truncate(:second)
    end
  end
end
