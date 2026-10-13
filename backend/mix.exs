defmodule Ortovicino.MixProject do
  use Mix.Project
  def project, do: [app: :ortovicino, version: "0.2.0", elixir: "~> 1.16", start_permanent: Mix.env() == :prod, deps: deps()]
  def application, do: [extra_applications: [:logger, :crypto], mod: {Ortovicino.Application, []}]
  defp deps, do: [
    {:plug_cowboy, "~> 2.7"}, {:ecto_sql, "~> 3.12"},
    {:ecto_sqlite3, "~> 0.17"}, {:jason, "~> 1.4"},
    {:bcrypt_elixir, "~> 3.2"}
  ]
end
