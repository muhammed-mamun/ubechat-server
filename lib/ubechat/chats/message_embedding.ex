defmodule Ubechat.Chats.MessageEmbedding do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_embeddings" do
    field(:conversation_id, :string)
    field(:sent_at, :integer)
    field(:sender_id, :integer)
    field(:embedding, Pgvector.Ecto.Vector)

    timestamps(type: :utc_datetime)
  end

  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [:conversation_id, :sent_at, :sender_id, :embedding])
    |> validate_required([:conversation_id, :sent_at, :sender_id, :embedding])
  end
end
