# e2e_messaging_test.exs
# Run with: mix run e2e_messaging_test.exs

alias Ubechat.Accounts

defmodule ChatClient do
  use WebSockex

  # State: %{name: "Alice", target_room: "chat:x:y", role: :sender | :receiver, received: []}

  def start_link(url, name, target_room, role) do
    state = %{name: name, target_room: target_room, role: role, received: []}
    WebSockex.start_link(url, __MODULE__, state)
  end

  def handle_connect(_conn, state) do
    IO.puts("[#{state.name}] Connected to WebSocket.")
    send(self(), :join_room)
    {:ok, state}
  end

  def handle_info(:join_room, state) do
    join_msg = ["1", "1", state.target_room, "phx_join", %{}]
    {:reply, {:text, Jason.encode!(join_msg)}, state}
  end

  def handle_info({:send_msg, text}, state) do
    chat_msg = ["1", "2", state.target_room, "new_msg", %{"ciphertext" => text}]
    IO.puts("[#{state.name}] Sending message: '#{text}'")
    {:reply, {:text, Jason.encode!(chat_msg)}, state}
  end

  def handle_frame({:text, msg}, state) do
    [join_ref, ref, topic, event, payload] = Jason.decode!(msg)
    
    cond do
      event == "phx_reply" and ref == "1" ->
        IO.puts("[#{state.name}] Successfully joined room: #{topic}")
        
        # If this is the sender, send a test message.
        if state.role == :sender do
          :timer.sleep(1000) # wait a moment to make sure everyone is ready
          send(self(), {:send_msg, "Hello from #{state.name}!"})
        end
        {:ok, state}
        
      event == "new_msg" ->
        ciphertext = payload["ciphertext"]
        sender_id = payload["sender_id"]
        IO.puts("\n>>> [#{state.name}] Received message from ID(#{sender_id}): '#{ciphertext}'\n")
        
        if state.role == :receiver do
          # The receiver successfully got the message. 
          # Stop the script with success code.
          IO.puts("✅ Messaging test successful! Both users connected and communicated.")
          System.halt(0)
        end
        
        {:ok, state}
        
      true ->
        # Ignore other events
        {:ok, state}
    end
  end
end

IO.puts("--- E2E Messaging Test ---")
now_unix = :os.system_time(:second)

# 1. Create Users
alice_attrs = %{
  display_name: "Alice", 
  email: "alice#{now_unix}@test.com", 
  plain_password: "password123"
}
bob_attrs = %{
  display_name: "Bob", 
  email: "bob#{now_unix}@test.com", 
  plain_password: "password123"
}

{:ok, alice} = Accounts.register_user(alice_attrs)
{:ok, bob} = Accounts.register_user(bob_attrs)

IO.puts("Registered Alice (ID: #{alice.id}) & Bob (ID: #{bob.id}).")

# 2. Generate Tokens
{:ok, alice_token} = Ubechat.Auth.Token.generate(alice.id)
{:ok, bob_token}   = Ubechat.Auth.Token.generate(bob.id)

# 3. Create Unique Room ID
room_id = "chat:#{Ubechat.Messages.conversation_id(alice.id, bob.id)}"
IO.puts("Starting chat in room: #{room_id}...")

# 4. Boot up WebSocket clients (Assuming server holds on localhost:4000)
alice_url = "ws://localhost:4000/socket/websocket?vsn=2.0.0&token=#{alice_token}"
bob_url   = "ws://localhost:4000/socket/websocket?vsn=2.0.0&token=#{bob_token}"

# Start Bob first so he can listen
{:ok, _bob_pid} = ChatClient.start_link(bob_url, "Bob", room_id, :receiver)
:timer.sleep(1000)

# Start Alice to send message
{:ok, _alice_pid} = ChatClient.start_link(alice_url, "Alice", room_id, :sender)

# 5. Wait for finish
:timer.sleep(15000)
IO.puts("❌ Test timed out...")
System.halt(1)
