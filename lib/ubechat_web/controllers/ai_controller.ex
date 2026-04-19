defmodule UbechatWeb.AiController do
  use UbechatWeb, :controller
  import Ecto.Query
  import Pgvector.Ecto.Query

  alias Ubechat.Graph
  alias Ubechat.Embeddings

  @doc """
  Executes a semantic vector search across chat and calendar data.
  """
  def search(conn, %{"query" => query_text}) do
    user = conn.assigns.current_user
    embedding = Embeddings.generate(query_text)

    # Search calendar events
    calendar_results =
      Ubechat.Repo.all(
        from(e in Ubechat.Calendar.Event,
          where: e.user_id == ^user.id,
          order_by: [asc: l2_distance(e.embedding, ^embedding)],
          limit: 5
        )
      )

    # Search chat messages
    chat_results =
      Ubechat.Repo.all(
        from(c in Ubechat.Chats.MessageEmbedding,
          where: c.sender_id == ^user.id,
          order_by: [asc: l2_distance(c.embedding, ^embedding)],
          limit: 5
        )
      )

    json(conn, %{
      calendar: Enum.map(calendar_results, &%{summary: &1.summary, start: &1.start_time}),
      chats: Enum.map(chat_results, &%{room: &1.conversation_id, time: &1.sent_at})
    })
  end

  @doc """
  Executes a Graph traversal query. Restricted to Cypher syntax for AI Agents.
  """
  def graph_query(conn, %{"cypher" => cypher, "params" => params}) do
    case Graph.query(cypher, params) do
      {:ok, rows} -> json(conn, %{data: rows})
      {:error, err} -> conn |> put_status(400) |> json(%{error: inspect(err)})
    end
  end
end
