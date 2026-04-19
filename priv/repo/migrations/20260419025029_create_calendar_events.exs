defmodule Ubechat.Repo.Migrations.CreateCalendarEvents do
  use Ecto.Migration

  def change do
    create table(:calendar_events) do
      add :user_id, references(:users, on_delete: :delete_all, type: :id), null: false
      add :google_event_id, :string, null: false
      add :summary, :string
      add :description, :text
      add :start_time, :utc_datetime, null: false
      add :end_time, :utc_datetime, null: false
      add :embedding, :vector, size: 384

      timestamps(type: :utc_datetime)
    end

    create unique_index(:calendar_events, [:user_id, :google_event_id])
  end
end
