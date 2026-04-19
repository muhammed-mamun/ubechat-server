defmodule UbechatWeb.SystemChannel do
  use UbechatWeb, :channel
  alias UbechatWeb.Presence

  @doc """
  Users join the "system:status" channel to broadcast their presence 
  and receive updates on who else is online.
  """
  @impl true
  def join("system:status", _payload, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id

    # Track this socket's presence
    {:ok, _} =
      Presence.track(socket, user_id, %{
        online_at: :os.system_time(:second),
        # You can add more public profile fields here if needed by the frontend
        status: "active"
      })

    # Push the current presence state down to the newly connected client
    push(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end
end
