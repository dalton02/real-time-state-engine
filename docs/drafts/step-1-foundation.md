## O que foi feito

Das implementações e estudos desta primeira etapa:

- Estudos a cerca do ecossistema Erlang/OTP e do framework Phoenix
- Geração automática do sistema de autenticação via `phx.gen.auth`
- Configuração do banco SQLite3 e criação das migrations do contexto Telemetry
- Desenho dos limites de domínio entre a camada web e a camada de persistência

---

## Autenticação (Contexto Accounts)

Totalmente gerado pelo `phx.gen.auth`, nada foi alterado na lógica de autenticação.
O generator produziu as tabelas `users` e `users_tokens`, o contexto `App.Accounts`
com registro, login e gerenciamento de sessão, e os hooks de autenticação.

A única customização foi no layout das páginas de login e registro, adaptado
ao tema visual do projeto.

---

## Banco de Dados (SQLite3)

Configurado com o adapter do Ecto. Foram criadas duas tabelas
dentro do contexto Telemetry.

### `nodes`

Tabela de registro das máquinas da planta.

Foi adicionado um index único em `machine_identifier`, pois cada máquina é única
no sistema. Isso cria internamente uma estrutura de busca mais eficiente no banco.

### `node_metrics`

Tabela que guarda o estado mais recente de cada sensor.

Foi adicionada uma chave estrangeira em `node_id` referenciando sua entrada em
`nodes`, criando o relacionamento entre as duas tabelas e permitindo buscas
associativas. O `node_id` também carrega um index único, o que garante que cada
node terá no máximo uma linha de métricas.

Em ambas as tabelas foi adicionado `timestamps()` seguindo o padrão e boas
práticas do Ecto, que gera automaticamente os campos `inserted_at` e `updated_at`
gerenciados pelo framework.

---

## Contexto Telemetry

Todo acesso ao banco passa pelo contexto `App.Telemetry`, que age como a fronteira
pública do domínio.

Foram criados 3 arquivos:

**`node.ex`** — schema da entidade Node com o changeset responsável pelas
validações de campos antes de qualquer operação no banco.

**`node_metrics.ex`** — mesmo padrão acima, para com node_metrics.

**`telemetry.ex`** — contém as regras de negócio do contexto. Por enquanto
expõe funções para listar, criar e buscar nodes, além do `upsert_node_metrics`
que sera usado mais para frente.

```
app_web/          →   só chama App.Telemetry
App.Telemetry     →   fronteira pública do domínio
App.Repo          →   nunca acessado diretamente pela web
```

Essa separação é deliberada. No Step 2, quando houver a implementação do GenServer e o ETS, apenas as ações do
`App.Telemetry` mudam, a camada web não percebe diferença nenhuma.

---

## Arquitetura atual

```
┌─────────────────────────────────────┐
│           app_web/                  │
│   Router · LiveViews                │
│                                     │
│   chama apenas App.Telemetry        │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│         App.Telemetry               │
│                                     │
│   register_node/1                   │
│   get_node/1                        │
│   list_nodes/0                      │
│   upsert_node_metrics/1             │
└────────────────┬────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────┐
│         SQLite3 via Ecto            │
│                                     │
│   nodes                             │
│   node_metrics                      │
└─────────────────────────────────────┘
```

---

## Testes

Foram escritos testes de integração para o contexto `App.Telemetry` cobrindo
as três operações implementadas nesta etapa. Cada teste roda dentro de uma
transaction isolada via `App.DataCase`, que faz rollback automático ao final
— garantindo que nenhum teste contamina o estado do próximo.

### `register nodes`

- Criação com params válidos
- Falha com `machine_identifier` duplicado — valida o unique constraint
- Falha com campos obrigatórios ausentes — valida o changeset antes de chegar no banco

### `list nodes`

- Retorna lista vazia quando não há nodes cadastrados
- Retorna todos os nodes existentes

### `get node`

- Retorna o node quando encontrado por `machine_identifier`
- Retorna `nil` quando não encontrado

O caso de duplicidade é o mais importante desta suite pois prova que a
constraint está funcionando tanto no changeset quanto no banco.
