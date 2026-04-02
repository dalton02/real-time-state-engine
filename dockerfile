FROM elixir:1.17-alpine AS builder

RUN apk add --no-cache build-base git python3 sqlite sqlite-dev

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod

COPY config config/

RUN MIX_ENV=prod mix deps.compile

COPY . .

RUN MIX_ENV=prod mix assets.deploy

RUN MIX_ENV=prod mix compile

RUN MIX_ENV=prod mix release

FROM elixir:1.17-alpine AS runtime

RUN apk add --no-cache sqlite sqlite-libs bash openssl

WORKDIR /app

COPY entrypoint.sh ./entrypoint.sh

COPY --from=builder /app/_build/prod/rel/app ./

EXPOSE 4000

CMD ["sh", "/app/entrypoint.sh"]
