defmodule ChatApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Start the PubSub system FIRST
      {Phoenix.PubSub, name: ChatApp.PubSub},

      # Start the Presence tracker (now it will find PubSub)
      ChatAppWeb.Presence,

      # Start the endpoint when the application starts
      ChatAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ChatApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def config_change(changed, _new, removed) do
    ChatAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
