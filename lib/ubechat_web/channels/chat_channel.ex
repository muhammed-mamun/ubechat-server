defmodule UbechatWeb.ChatChannel do
  use UbechatWeb, :channel
  alias Ubechat.Messages

  @doc """
  Authorizes the user to join a specific 1-on-1 chat room.
  Room names must look like "chat:user1Id:user2Id" where IDs are sorted alphabetically.
  """
  @impl true
  def join("chat:" <> room_id, _payload, socket) do
    # Only allow joining if the current user ID is part of the room_id
    user_id = socket.assigns.user_id

    # The room_id is assumed to be constructed as "id1:id2"
    if String.contains?(room_id, user_id) do
      # Fetch recent history
      case Messages.list_messages(room_id, 50) do
        {:ok, recent_messages} ->
          {:ok, %{messages: recent_messages}, assign(socket, :room_id, room_id)}

        {:error, _reason} ->
          {:error, %{reason: "Could not fetch message history"}}
      end
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @doc """
  Handles incoming new messages from a client, persists to ScyllaDB,
  and broadcasts to all subscribers in the room (which includes the sender).
  """
  @impl true
  def handle_in("new_msg", %{"ciphertext" => ciphertext}, socket) do
    IO.inspect(ciphertext, label: "GOT CIPHERTEXT")
    room_id = socket.assigns.room_id
    sender_id = socket.assigns.user_id
    now_ms = :os.system_time(:millisecond)

    case Messages.insert_message(room_id, sender_id, ciphertext, now_ms) do
      {:ok, msg} ->
        broadcast!(socket, "new_msg", msg)
        {:reply, :ok, socket}

      {:error, reason} ->
        {:reply, {:error, %{reason: inspect(reason)}}, socket}
    end
  end

  # Optional catch-all for unknown events
  @impl true
  def handle_in(_event, _payload, socket) do
    {:reply, :error, socket}
  end
end
