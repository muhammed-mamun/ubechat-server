defmodule UbechatWeb.ChatChannelTest do
  use ExUnit.Case
  import Phoenix.ChannelTest
  @endpoint UbechatWeb.Endpoint

  setup do
    {:ok, _, socket} =
      UbechatWeb.UserSocket
      |> socket("user_socket:tester-id-1", %{user_id: "tester-id-1"})
      |> subscribe_and_join(UbechatWeb.ChatChannel, "chat:tester-id-1:tester-id-2")

    %{socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "new_msg", %{"ciphertext" => "SecureTest"})
    
    # We should get a reply
    assert_reply ref, :ok
    
    # And we should get a broadcast
    assert_broadcast "new_msg", %{ciphertext: "SecureTest"}
  end
end
