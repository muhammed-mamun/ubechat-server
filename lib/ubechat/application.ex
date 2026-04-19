defmodule Ubechat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    scylla_opts = Application.get_env(:ubechat, :scylla, [])

    children = [
      UbechatWeb.Telemetry,
      Ubechat.Repo,
      {Xandra.Cluster, Keyword.put(scylla_opts, :name, Ubechat.Scylla)},
      {DNSCluster, query: Application.get_env(:ubechat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Ubechat.PubSub},
      UbechatWeb.Presence,
      {Nx.Serving,
       serving: Ubechat.Embeddings.serving(), name: Ubechat.Embeddings.Serving, batch_timeout: 100},
      {Oban, Application.fetch_env!(:ubechat, Oban)},
      # Start a worker by calling: Ubechat.Worker.start_link(arg)
      # {Ubechat.Worker, arg},
      # Start to serve requests, typically the last entry
      UbechatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ubechat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UbechatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
