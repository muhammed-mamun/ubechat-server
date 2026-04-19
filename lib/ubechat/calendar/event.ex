defmodule Ubechat.Calendar.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "calendar_events" do
    field :google_event_id, :string
    field :summary, :string
    field :description, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :embedding, Pgvector.Ecto.Vector
    
    belongs_to :user, Ubechat.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:google_event_id, :summary, :description, :start_time, :end_time, :embedding, :user_id])
    |> validate_required([:google_event_id, :start_time, :end_time, :user_id])
    |> unique_constraint([:user_id, :google_event_id])
  end
end
