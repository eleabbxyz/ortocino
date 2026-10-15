defmodule Ortovicino.Application do
  use Application
  def start(_type, _args) do
    children = [
      Ortovicino.Repo,
      {Registry, keys: :duplicate, name: Ortovicino.ChatRegistry},
      Ortovicino.RateLimiter,
      {Plug.Cowboy, scheme: :http, plug: OrtovicinoWeb.Router,
       options: [port: Application.fetch_env!(:ortovicino, :port), ip: Application.fetch_env!(:ortovicino, :ip)]}
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: Ortovicino.Supervisor)
  end
end
