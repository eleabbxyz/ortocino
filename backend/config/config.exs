import Config

config :ortovicino, ecto_repos: [Ortovicino.Repo]
config :ortovicino, Ortovicino.Repo,
  database: System.get_env("DATABASE_PATH", Path.expand("../ortovicino.sqlite3", __DIR__)),
  pool_size: 5

{:ok, listen_ip} = :inet.parse_address(String.to_charlist(System.get_env("BIND_IP", "127.0.0.1")))
config :ortovicino, port: String.to_integer(System.get_env("PORT", "4000")), ip: listen_ip
