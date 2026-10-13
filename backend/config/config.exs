import Config

config :ortovicino, ecto_repos: [Ortovicino.Repo]
config :ortovicino, Ortovicino.Repo,
  database: Path.expand("../ortovicino.sqlite3", __DIR__),
  pool_size: 5

config :ortovicino, port: String.to_integer(System.get_env("PORT", "4000"))
