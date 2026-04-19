# Script to initialize ScyllaDB schema.
# Run via: mix run lib/ubechat/scylla_schema.exs

scylla_opts = Application.get_env(:ubechat, :scylla, [])

IO.puts("Connecting to Scylla nodes: #{inspect(scylla_opts[:nodes])}")

{:ok, conn} = Xandra.start_link(nodes: scylla_opts[:nodes])

keyspace = scylla_opts[:keyspace] || "ubechat"

# 1. Create Keyspace
cql_keyspace = """
CREATE KEYSPACE IF NOT EXISTS #{keyspace}
WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};
"""

IO.puts("Creating keyspace '#{keyspace}'...")
Xandra.execute!(conn, cql_keyspace, [])

# 2. Use Keyspace
Xandra.execute!(conn, "USE #{keyspace}", [])

# 3. Create Messages Table
cql_table = """
CREATE TABLE IF NOT EXISTS messages (
  conversation_id text,
  sent_at bigint,
  sender_id text,
  ciphertext text,
  PRIMARY KEY (conversation_id, sent_at)
) WITH CLUSTERING ORDER BY (sent_at ASC);
"""

IO.puts("Creating table 'messages'...")
Xandra.execute!(conn, cql_table, [])

IO.puts("ScyllaDB schema initialized successfully.")

# Close connection
GenServer.stop(conn)
