defmodule Ubechat.Graph do
  @moduledoc "Context for interacting with the Memgraph AI Layer."

  @doc """
  Logs a chat message natively into the graph memory.
  This builds contextual vectors for an AI agent to traverse conversation webs instantly.
  """
  def log_chat_message(conversation_id, sender_id, ciphertext, sent_at) do
    # Perform asynchronously to ensure Websockets are never blocked by Graph failures
    Task.start(fn ->
      # 1. Generate embedding and save to Postgres
      embedding = Ubechat.Embeddings.generate(ciphertext)

      %Ubechat.Chats.MessageEmbedding{}
      |> Ubechat.Chats.MessageEmbedding.changeset(%{
        conversation_id: conversation_id,
        sent_at: sent_at,
        sender_id: sender_id,
        embedding: embedding
      })
      |> Ubechat.Repo.insert()

      # 2. Sync to Memgraph
      cypher = """
      MERGE (u:User {id: $sender_id})
      MERGE (room:Room {id: $conversation_id})
      CREATE (m:Message {ciphertext: $ciphertext, sent_at: $sent_at})
      CREATE (u)-[:SENT]->(m)
      CREATE (m)-[:DELIVERED_TO]->(room)
      """

      params = %{
        "sender_id" => to_string(sender_id),
        "conversation_id" => conversation_id,
        "ciphertext" => ciphertext,
        "sent_at" => sent_at
      }

      execute_cypher(cypher, params)
    end)
  end

  @doc """
  Logs a calendar event natively into the graph memory.
  Links (User)-[:ATTENDS]->(Event).
  """
  def log_calendar_event(user_id, google_id, summary, start_time, end_time) do
    Task.start(fn ->
      cypher = """
      MERGE (u:User {id: $user_id})
      MERGE (e:Event {google_id: $google_id})
      SET e.summary = $summary, e.start_time = $start_time, e.end_time = $end_time
      MERGE (u)-[:ATTENDS]->(e)
      """

      params = %{
        "user_id" => to_string(user_id),
        "google_id" => google_id,
        "summary" => summary,
        "start_time" => DateTime.to_iso8601(start_time),
        "end_time" => DateTime.to_iso8601(end_time)
      }

      execute_cypher(cypher, params)
    end)
  end

  @doc """
  Executes a raw Cypher query against Memgraph and returns the rows.
  Useful for the AI Agent to perform complex traversals.
  """
  def query(cypher, params \\ %{}) do
    execute_cypher(cypher, params)
  end

  defp execute_cypher(cypher, params) do
    host = System.get_env("MEMGRAPH_HOST") || "127.0.0.1"
    host_charlist = to_charlist(host)

    with {:ok, sock} <-
           :gen_tcp.connect(host_charlist, 7687, active: false, mode: :binary, packet: :raw),
         :ok <- Boltex.Bolt.handshake(:gen_tcp, sock),
         {:ok, _info} <- Boltex.Bolt.init(:gen_tcp, sock, {}),
         {:ok, rows} <- Boltex.Bolt.run_statement(:gen_tcp, sock, cypher, params) do
      :gen_tcp.close(sock)
      {:ok, rows}
    else
      {:error, err} ->
        require Logger
        Logger.warning("Memgraph execution error: #{inspect(err)}")
        {:error, err}
    end
  end
end
