defmodule Ubechat.Messages do
  @moduledoc """
  Context for interacting with the ScyllaDB messages table.
  Since we use Xandra, this directly executes CQL.
  """

  @xandra_conn Ubechat.Scylla

  @doc """
  Inserts a new message into a conversation.
  """
  def insert_message(conversation_id, sender_id, ciphertext, sent_at_ms \\ nil) do
    sent_at_ms = sent_at_ms || :os.system_time(:millisecond)

    cql = """
    INSERT INTO messages (conversation_id, sent_at, sender_id, ciphertext)
    VALUES (?, ?, ?, ?)
    """

    params = [
      {"text", conversation_id},
      {"bigint", sent_at_ms},
      {"text", sender_id},
      {"text", ciphertext}
    ]

    case Xandra.Cluster.run(@xandra_conn, fn conn -> Xandra.execute(conn, cql, params) end) do
      {:ok, _result} ->
        {:ok,
         %{
           conversation_id: conversation_id,
           sent_at: sent_at_ms,
           sender_id: sender_id,
           ciphertext: ciphertext
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Fetches recent messages for a conversation.
  Optionally paginates using `before_ms` (fetching messages older than this timestamp).
  """
  def list_messages(conversation_id, limit \\ 50, before_ms \\ nil) do
    if before_ms do
      cql = """
      SELECT conversation_id, sent_at, sender_id, ciphertext 
      FROM messages 
      WHERE conversation_id = ? AND sent_at < ? 
      ORDER BY sent_at DESC LIMIT ?
      """

      params = [{"text", conversation_id}, {"bigint", before_ms}, {"int", limit}]
      execute_fetch(cql, params)
    else
      cql = """
      SELECT conversation_id, sent_at, sender_id, ciphertext 
      FROM messages 
      WHERE conversation_id = ? 
      ORDER BY sent_at DESC LIMIT ?
      """

      params = [{"text", conversation_id}, {"int", limit}]
      execute_fetch(cql, params)
    end
  end

  defp execute_fetch(cql, params) do
    case Xandra.Cluster.run(@xandra_conn, fn conn -> Xandra.execute(conn, cql, params) end) do
      {:ok, %Xandra.Page{} = page} ->
        messages = Enum.map(page, fn row ->
          %{
            conversation_id: row["conversation_id"],
            sent_at: row["sent_at"],
            sender_id: row["sender_id"],
            ciphertext: row["ciphertext"]
          }
        end)

        # ScyllaDB ORDER BY DESC gives us newest first, but we usually want ascending order in UI
        {:ok, Enum.reverse(messages)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Helper to consistently generate a unique string ID for a 1-on-1 discussion 
  given two user IDs.
  Formats as: "userA_id:userB_id" (alphabetically sorted so both users get the same string).
  """
  def conversation_id(user_1_id, user_2_id) do
    [to_string(user_1_id), to_string(user_2_id)]
    |> Enum.sort()
    |> Enum.join(":")
  end
end
