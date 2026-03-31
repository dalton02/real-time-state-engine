## O que foi feito nesta etapa

Das implementações desta segunda etapa:

- Construção do sistema de ingestão de eventos via GenServer
- Criação da tabela ETS como camada transacional em memória
- Implementação do mecanismo Write-Behind para persistência assíncrona no SQLite
- Árvore de supervisão OTP para garantir resiliência dos processos
- Testes de integração cobrindo o ETS e o Write-Behind

---

## Arquitetura da camada de ingestão

```
evento chega
     │
     ▼
App.Telemetry.Ingestion.Server   (GenServer)
     │
     ├── atualiza ETS :w_core_telemetry_cache
     │
     │
     └── (a cada 5 segundos)
              │
              ▼
     App.Telemetry.Ingestion.Worker   (GenServer)
              │
              ├── lê todo o ETS
              └── upsert em lote → SQLite via App.Telemetry
```

---

## Os três processos

### `App.Telemetry.Ingestion.Server`

Responsável por receber os eventos e gravar no ETS. Toda operação de escrita
passa por ele.

A tabela ETS é criada no `init/1` do Server e pertence a ele. Se o Server
cair, a tabela some junto, abaixo explico o porquê disso levar a minha estrategia de supervisão.

O `add_metric/1` usa duas operações ETS em sequência:

```elixir
# 1. Incrementa o contador atomicamente — se a linha não existe, cria com valor padrão
:ets.update_counter(
  :w_core_telemetry_cache,
  metrics.node_id,
  {3, 1},
  {metrics.node_id, metrics.status, 0, metrics.last_payload, metrics.timestamp}
)

# 2. Atualiza os demais campos
:ets.update_element(:w_core_telemetry_cache, metrics.node_id, [
  {2, metrics.status},
  {4, metrics.last_payload},
  {5, metrics.timestamp}
])
```

O `update_counter` é atômico no nível do BEAM — não há condição de corrida
no incremento do `event_count`, mesmo sob carga concorrente intensa.

### `App.Telemetry.Ingestion.Worker`

Responsável pelo Write-Behind — varre o ETS a cada 5 segundos e persiste
o estado atual no SQLite via `App.Telemetry.upsert_node_metrics/1`.

O loop é implementado com `handle_info` e `Process.send_after`, sem bloqueio:

```elixir
def init(:ok) do
  schedule_sweep()
  {:ok, nil}
end

def handle_info(:sweep, state) do
  do_sweep()
  schedule_sweep()
  {:noreply, state}
end

defp schedule_sweep do
  if Mix.env() != :test do
    Process.send_after(self(), :sweep, 5_000)
  end
end
```

Em ambiente de teste o agendamento automático é desabilitado — o sweep é
chamado manualmente via `Worker.do_sweep()`, dando controle total ao teste.

O Worker não acessa o `Repo` diretamente — passa pelo contexto `App.Telemetry`,
mantendo o limite de domínio estabelecido no Step 1.

### `App.Telemetry.Ingestion.Supervisor`

Supervisiona os dois processos acima com estratégia `:rest_for_one`:

```elixir
children = [
  App.Telemetry.Ingestion.Server,   # 1º
  App.Telemetry.Ingestion.Worker    # 2º
]

Supervisor.init(children, strategy: :rest_for_one)
```

---

## Defesa das decisões

### Por que `:set` no ETS?

A tabela foi criada com o tipo `:set`:

```elixir
:ets.new(:w_core_telemetry_cache, [:set, :protected, :named_table, read_concurrency: true])
```

Cada `node_id` é único — um node tem exatamente uma linha de estado atual.
O tipo `:set` garante isso estruturalmente, da mesma forma que um `Map` em
Elixir onde a chave é única.

### Por que `:protected` e não `:public`?

Com `:protected`, apenas o processo dono (o Server) pode escrever na tabela.
Qualquer outro processo pode ler. Isso é intencional — toda escrita passa pelo
Server, que serializa o acesso e garante consistência.

### Por que `read_concurrency: true`?

O dashboard vai ter múltiplos usuários lendo o ETS simultaneamente. Essa
flag otimiza internamente o ETS para leituras concorrentes, reduzindo
contenção entre os processos leitores.

### Por que `:rest_for_one` e não `:one_for_all`?

A dependência entre os processos é **assimétrica**:

```
Server cai  →  ETS some  →  Worker não tem mais o que ler  →  ambos reiniciam
Worker cai  →  ETS intacto  →  Server continua acumulando  →  só Worker reinicia
```

Com `:one_for_all`, se o Worker cair por qualquer motivo, o Server reiniciaria
junto — destruindo todos os dados em memória que ainda não foram persistidos.
Com `:rest_for_one`, a ordem dos children determina o comportamento: se um
processo cai, apenas ele e os processos **depois dele** na lista reiniciam.
Como o Server está em primeiro lugar, sua queda reinicia tudo. A queda do
Worker (segundo) reinicia só ele.

### Por que Write-Behind e não escrita síncrona?

Escrever no SQLite a cada evento seria o gargalo que este sistema existe para
eliminar. O SQLite não suporta escritas concorrentes — cada `INSERT` é
serializado. Com sensores enviando pulsos a cada poucos segundos, isso
resultaria em lock constante, exatamente o problema do sistema legado.

O Write-Behind resolve isso absorvendo o tsunami de eventos no ETS
(memória, microssegundos) e persistindo em lote a cada 5 segundos. O SQLite
recebe uma fração das escritas, sem contenção.

---

## Testes

Assim como na etapa anterior, aqui também é feito a escrita de testes, principalmente para garantir a qualidade e confiabilidade de todas as funções do nossos sistema até agora.

Foram escritos testes de integração cobrindo as duas responsabilidades
principais desta etapa.

### ETS persistence

Valida que o Server grava e atualiza corretamente no ETS:

- Criação da entrada quando o node ainda não existe na tabela
- Incremento correto do `event_count` sob múltiplos eventos — prova que
  o `update_counter` atômico não perde contagem nem sob 400 eventos sequenciais

### Write-Behind Mechanism

Valida o fluxo completo da memória até o banco:

- Evento entra no ETS via Server
- `Worker.do_sweep()` é chamado manualmente
- O banco é consultado diretamente e o estado é comparado campo a campo

O teste de Write-Behind expõe um detalhe importante do SQLite + Ecto: o
campo `last_payload` é armazenado como JSON e desserializado com chaves
string. A comparação requer conversão explícita de volta para átomos:

```elixir
Map.new(nodeDB.last_payload, fn {k, v} -> {String.to_existing_atom(k), v} end)
```

---

## Arquitetura atualizada

```
┌─────────────────────────────────────────────────┐
│                  app_web/                        │
│          Router · LiveViews                      │
│                                                  │
│   lê ETS diretamente (dados quentes)             │
│   chama App.Telemetry (dados frios)              │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│              App.Telemetry                       │
│                                                  │
│   register_node/1                                │
│   list_nodes/0                                   │
│   get_node/1                                     │
│   upsert_node_metrics/1   ◄── chamado pelo Worker│
└───────────────────┬─────────────────────────────┘
                    │
          ┌─────────┴──────────┐
          ▼                    ▼
┌─────────────────┐  ┌────────────────────────────┐
│  SQLite (Ecto)  │  │  App.Telemetry.Ingestion    │
│                 │  │                             │
│  nodes          │  │  Supervisor (:rest_for_one) │
│  node_metrics   │  │  ├── Server → ETS           │
│                 │  │  └── Worker → Write-Behind  │
└─────────────────┘  └────────────────────────────┘
```
