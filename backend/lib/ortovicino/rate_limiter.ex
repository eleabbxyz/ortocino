defmodule Ortovicino.RateLimiter do
  use GenServer
  def start_link(_), do: GenServer.start_link(__MODULE__, [], name: __MODULE__)
  def init(_) do
    :ets.new(:ortovicino_rate_limit, [:named_table, :public, :set, write_concurrency: true])
    {:ok, %{}}
  end
end
