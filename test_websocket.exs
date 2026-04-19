# test_websocket.exs
# run via: mix run test_websocket.exs

# 1. Generate token
{:ok, token} = Ubechat.Auth.Token.generate("tester-id-1")

{url, opts} = {"ws://localhost:4000/socket/websocket?vsn=2.0.0&token=#{token}", []}

{:ok, parent} = Task.start(fn -> 
  IO.puts("Start test task...")
  receive do
    :done -> IO.puts("Done.")
  end
end)

defmodule Client do
  use WebSockex

  def start_link(url) do
    WebSockex.start_link(url, __MODULE__, %{})
  end

  def handle_connect(_conn, state) do
    IO.puts("Connected!")
    send(self(), :join)
    {:ok, state}
  end

  def handle_info(:join, state) do
    # V2 format: [join_ref, ref, topic, event, payload]
    join_msg = ["1", "1", "chat:tester-id-1:tester-id-2", "phx_join", %{}]
    {:reply, {:text, Jason.encode!(join_msg)}, state}
  end

  def handle_frame({:text, msg}, state) do
    # Decode V2 array format
    [join_ref, ref, topic, event, payload] = Jason.decode!(msg)
    IO.puts("Received frame: [#{join_ref}, #{ref}, #{topic}, #{event}, #{inspect(payload)}]")
    
    if event == "phx_reply" and ref == "1" do
      IO.puts("Join successful, sending message...")
      
      chat_msg = ["1", "2", "chat:tester-id-1:tester-id-2", "new_msg", %{"ciphertext" => "SecureMessage123"}]
      {:reply, {:text, Jason.encode!(chat_msg)}, state}
    end

    if event == "new_msg" do
      IO.puts("Received broadcast: #{inspect(payload)}")
      # Wait a second then exit
      spawn(fn -> 
        Process.sleep(1000)
        System.halt(0)
      end)
    end

    {:ok, state}
  end
end

case Client.start_link(url) do
  {:ok, _pid} -> 
    Process.sleep(5000)
    IO.puts("Timeout waiting for message!")
    System.halt(1)
  error -> 
    IO.puts("Error connecting: #{inspect(error)}")
    System.halt(1)
end
