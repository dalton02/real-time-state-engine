## O que foi feito nesta etapa

Das implementações desta quinta e última etapa:

- Dockerfile multi-stage gerando uma `mix release` otimizada para edge computing
- Script `entrypoint.sh` rodando migrations e seed automaticamente no boot
- Módulo `App.Release` com migrations e criação do usuário seed em produção
- Persistência do SQLite garantida via Docker volume
- Geração automática de secret_key_base para toda execução do container

---

## Dockerfile

### Multi-stage build

O Dockerfile usa dois estágios para manter a imagem final enxuta:

```
Stage 1: builder  →  compila, gera assets, cria a release
Stage 2: runtime  →  copia só os artefatos da release, sem a toolchain
```

O estágio `builder` instala `build-base`, `git`, `sqlite-dev` e outras
ferramentas de compilação que não precisam existir em produção. O estágio
`runtime` carrega apenas o necessário para executar a release — `sqlite-libs`,
`openssl` e `bash`.

### Geração do `SECRET_KEY_BASE` na build

Para facilitar o deploy em ambientes, foi criado um entrypoint.sh onde toda vez que a aplicação roda,
é definido uma nova SECRET_KEY_BASE para lidar principalmente com questão de geração de tokens para os usuários:

```sh
KEY_LENGTH=${KEY_LENGTH:-64}
RANDOM_KEY=$(openssl rand -base64 $((KEY_LENGTH * 3 / 4 + 1)) | tr -d '\n' | cut -c1-$KEY_LENGTH)

export SECRET_KEY_BASE="$RANDOM_KEY"
```

A secret geralmente é criada com mix phx.gen.secret, porém em runtime não possuimos um projeto inteiro do phoenix live view no sistema para isso.

---

## Entrypoint — boot sequence

O `entrypoint.sh` orquestra a inicialização em ordem:

```sh
#!/bin/sh
set -e


KEY_LENGTH=${KEY_LENGTH:-64}
RANDOM_KEY=$(openssl rand -base64 $((KEY_LENGTH * 3 / 4 + 1)) | tr -d '\n' | cut -c1-$KEY_LENGTH)

export SECRET_KEY_BASE="$RANDOM_KEY"
export DATABASE_PATH=/app/data/app.db

#Roda scripts de migration e geração de usuário
/app/bin/app eval "App.Release.migrate()"
/app/bin/app eval "App.Release.seed()"

echo "==> Iniciando aplicação..."

#Define que queremos executar um server http
export PHX_SERVER=true

#executa a aplicação
exec /app/bin/app start
```

Cada passo é idempotente — pode ser executado múltiplas vezes sem efeito
colateral. O `migrate()` só aplica migrations pendentes. O `seed()` verifica
se o usuário já existe antes de criar.

O `exec` no passo final substitui o processo shell pelo processo da release
— o PID 1 do container passa a ser a aplicação Elixir, não o shell. Isso
garante que sinais do Docker (`SIGTERM`, `SIGINT`) chegam diretamente na
aplicação e o graceful shutdown funciona corretamente.

---

## App.Release — migrations e seed em produção

O módulo `App.Release` expõe duas funções chamadas pelo entrypoint:

### `migrate/0`

Roda todas as migrations pendentes via `Ecto.Migrator`. Necessário porque
releases não rodam migrations automaticamente — diferente do `mix ecto.migrate`
em dev, em produção é responsabilidade da aplicação.

### `seed/0`

Cria o usuário administrador padrão se não existir:

```
email:    admin@wcore.com
password: ErlangIsCool
```

O usuário é criado via `App.Accounts.register_user/1` e depois tem a sua senha definida em `App.Accounts.update_user_password/2`. Após criar, o campo
`confirmed_at` é definido diretamente para pular o fluxo de confirmação
de email.

---

## Persistência do SQLite

O banco vive fora do container via volume Docker:

```bash
docker run -p 4000:4000 -v mydata:/app/data elixir
```

Sem o volume, o banco seria destruído a cada `docker stop`. Com o volume,
o banco sobrevive a restarts, updates de imagem e falhas.

---

## Como rodar

```bash
# 1. Build
docker build  . -t wcore

# 2. Run
docker run -p 4000:4000 -v wdata:/app/data  wcore

# 3. Acesse
# http://localhost:4000
# email:    admin@wcore.com
# password: ErlangIsCool
```

---

## Diagrama arquitetural final

```
┌──────────────────────────────────────────────────────────────────┐
│                        Docker Container                          │
│                                                                  │
│  entrypoint.sh                                                   │
│  ├── migrate()   →  SQLite migrations                            │
│  ├── seed()      →  admin user                                   │
│  └── start       →  Phoenix application                          │
│                            │                                     │
│              ┌─────────────┴──────────────┐                      │
│              ▼                            ▼                      │
│    ┌──────────────────┐      ┌────────────────────────────────┐  │
│    │   app_web/       │      │  App.Telemetry.Ingestion       │  │
│    │                  │      │                                │  │
│    │  Router          │      │  Supervisor (:rest_for_one)    │  │
│    │  LiveViews       │      │  ├── Server → ETS              │  │
│    │  Components      │      │  └── Worker → Write-Behind     │  │
│    └────────┬─────────┘      └───────────────┬────────────────┘  │
│             │                                │                   │
│             ▼                                ▼                   │
│    ┌──────────────────────────────────────────────────────────┐  │
│    │                    App.Telemetry                         │  │
│    │                                                          │  │
│    │   register_node · list_nodes · get_node                  │  │
│    │   ingest_event · persist_node_metrics · get_hot_data     │  │
│    └───────────────────────┬──────────────────────────────────┘  │
│                            │                                     │
│               ┌────────────┴───────────────┐                     │
│               ▼                            ▼                     │
│    ┌────────────────────┐      ┌───────────────────────────┐     │
│    │  ETS (memória)     │      │  SQLite (disco)           │     │
│    │                    │      │                           │     │
│    │  :w_core_telemetry │      │  nodes                    │     │
│    │  _cache            │      │  node_metrics             │     │
│    │                    │      │  users                    │     │
│    │  dados quentes     │      │  users_tokens             │     │
│    │  microssegundos    │      │                           │     │
│    └────────────────────┘      └────────────┬──────────────┘     │
│                                             │                    │
└─────────────────────────────────────────────┼────────────────────┘
                                              │ VOLUME
                                              ▼
                                   ┌─────────────────────┐
                                   │   host: ./data/     │
                                   │   app.db            │
                                   │                     │
                                   │   restarts          │
                                   └─────────────────────┘
```

---
