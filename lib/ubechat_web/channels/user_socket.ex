defmodule UbechatWeb.UserSocket do
  use Phoenix.Socket

  # Channel routing
  channel "chat:*", UbechatWeb.ChatChannel
  channel "system:status", UbechatWeb.SystemChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    case Ubechat.Auth.Token.user_id_from_token(token) do
      {:ok, user_id} ->
        # Typically we might check the DB to ensure the user exists, 
        # but the JWT verifies their identity securely.
        {:ok, assign(socket, :user_id, to_string(user_id))}

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
