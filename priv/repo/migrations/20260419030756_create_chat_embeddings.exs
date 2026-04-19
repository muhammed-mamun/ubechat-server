defmodule Ubechat.Repo.Migrations.CreateChatEmbeddings do
  use Ecto.Migration

  def change do
    create table(:chat_embeddings) do
      add(:conversation_id, :string, null: false)
      add(:sent_at, :bigint, null: false)
      add(:sender_id, :id, null: false)
      add(:embedding, :vector, size: 384)

      timestamps(type: :utc_datetime)
    end

    create(index(:chat_embeddings, [:conversation_id, :sent_at]))
  end
end
