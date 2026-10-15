FROM elixir:1.18-otp-27
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
RUN mix deps.get && mix deps.compile
COPY config ./config
COPY lib ./lib
COPY priv ./priv
COPY test ./test
RUN mix compile
CMD ["sh", "-c", "mix ecto.create && mix ecto.migrate && mix run priv/repo/seeds.exs && mix run --no-halt"]
