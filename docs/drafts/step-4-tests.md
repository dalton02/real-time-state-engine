## O que foi feito nesta etapa

Das implementações desta quarta etapa:

- Testes unitários dos changesets de `Node` e `NodeMetrics`
- Testes de integração do sistema de ingestão (ETS persistence e Write-Behind)
- Teste de stress com 10.000 eventos concorrentes distribuídos entre 5 nodes
- Prova via asserções que nenhum evento foi perdido no ETS nem no SQLite

---

## Suítes de teste

### 1. `App.Telemetry.NodeTest` — changeset unitário

Valida o contrato do changeset de `Node` antes de qualquer operação no banco.

```
| Teste                                   | O que prova                            |
|---                                      |                                     ---|
| `valid params produce valid changeset`  | campos corretos geram changeset válido |
| `missing machine_identifier is invalid` | campo obrigatório ausente é rejeitado  |
| `missing location is invalid`           | campo obrigatório ausente é rejeitado  |
```

O valor desses testes está na garantia de que **o banco nunca recebe dados
inválidos** — o changeset é a primeira linha de defesa antes do SQLite.

---

### 2. `App.Telemetry.NodeMetricsTest` — changeset unitário

Mesmo padrão acima, para `NodeMetrics`.

```
| Teste                                  | O que prova                                     |
|---                                      |                                             ---|
| `valid params produce valid changeset` | todos os campos corretos geram changeset válido |
| `missing node_id is invalid`           | métrica sem node referenciado é rejeitada       |
```

O teste de `node_id` ausente vai além de `refute changeset.valid?` — verifica
a mensagem de erro exata:

```elixir
assert %{node_id: ["can't be blank"]} = errors_on(changeset)
```

Isso garante que o erro retornado para a camada web é legível e correto.

---

### 3. `App.Telemetry.IngestionTest` — integração

Suíte mais importante. Testa o fluxo completo da ingestão com processos reais.

#### Setup

O `setup_all` inicializa o Supervisor manualmente — em testes o agendamento
automático do Worker está desabilitado, dando controle total sobre quando o
sweep acontece:

```elixir
setup_all do
  Supervisor.start_link("")
  {:ok, recipient: :world}
end
```

O `setup` de cada grupo limpa o ETS antes de cada teste via `Server.clear()`,
garantindo isolamento entre os casos.

---

#### ETS Persistence

**`creates a node_metric if do not exist`**

Prova que o primeiro evento de um node cria a entrada no ETS com
`event_count = 1` e todos os campos corretos:

```elixir
Server.add_metric(@metric_example)
data = Server.get_node(1)

assert {1, "operational", 1, last_payload, timestamp} == elem(data, 1)
```

**`correctly update event_count field`**

Prova que 400 eventos sequenciais resultam em `event_count = 400` — sem
perda, sem duplicata:

```elixir
for _ <- 1..400 do
  Server.add_metric(@metric_example)
end

data = Server.get_node(1)
assert {1, "operational", 400, _, _} = elem(data, 1)
```

Este teste prova que o `update_counter` atômico funciona corretamente
sob carga sequencial.

---

#### Write-Behind Mechanism

**`upsert the node_metrics into DB`**

Prova o ciclo completo: evento entra no ETS, sweep persiste no banco,
banco reflete o estado correto:

```elixir
Server.add_metric(@metric_example)
Process.sleep(400)
Worker.do_sweep()

nodeDB = Repo.get_by(NodeMetrics, node_id: 1)

assert {1, "operational", 1, last_payload, timestamp} ==
       {nodeDB.id, nodeDB.status, nodeDB.total_events_processed,
        Map.new(nodeDB.last_payload, fn {k, v} -> {String.to_existing_atom(k), v} end),
        nodeDB.last_seen_at}
```

O `Process.sleep(400)` garante que o cast do GenServer foi processado antes
do sweep. A conversão das chaves do payload de string para átomo é necessária
porque o SQLite serializa JSON com chaves string.

---

#### ETS Concurrency Stress — 10.000 workers

O teste central desta etapa. Prova resiliência sob concorrência real.

```elixir
test "10.000 workers" do
  total = 10000

  tasks =
    Enum.to_list(1..total)
    |> Enum.map(fn _ ->
      Task.async(fn ->
        node_id = Enum.random([1, 2, 3, 4, 5])
        Server.add_metric(%{node_id: node_id, status: "operational", ...})
      end)
    end)

  Task.await_many(tasks, :infinity)

  # Prova 1 — ETS não perdeu nenhum evento
  count =
    Server.list()
    |> Enum.reduce(0, fn item, acc -> elem(item, 2) + acc end)

  assert total == count

  # Prova 2 — SQLite sincronizou corretamente após o sweep
  Worker.do_sweep()

  count =
    Telemetry.list_node_and_metrics()
    |> Enum.reduce(0, fn item, acc ->
      item.node_metrics.total_events_processed + acc
    end)

  assert total == count
end
```

**O que está sendo provado:**

10.000 `Task.async` disparam simultaneamente, cada um mandando um evento
para um dos 5 nodes aleatoriamente. Todos os tasks rodam em paralelo.

Após `Task.await_many`, duas asserções encadeadas provam a integridade:

**Asserção 1 — ETS:** a soma de `event_count` de todos os nodes deve ser
exatamente 10.000. Qualquer race condition no incremento resultaria em um
número menor. O `update_counter` atômico garante que isso nunca acontece.

**Asserção 2 — SQLite:** após o `Worker.do_sweep()`, a soma de
`total_events_processed` no banco deve ser também 10.000. Prova que o
Write-Behind sincronizou o estado corretamente sem perda.

---

## Por que esse teste prova ausência de race condition

A race condition clássica num contador compartilhado seria:

```
Processo A: lê count = 5
Processo B: lê count = 5
Processo A: escreve count = 6
Processo B: escreve count = 6   ← perdeu um incremento
resultado: 6 em vez de 7
```

Com `:ets.update_counter/4`, o incremento é uma operação atômica no nível
do BEAM — não há janela entre leitura e escrita. Sob 10.000 processos
concorrentes, se a soma final for exatamente 10.000, a ausência de race
condition está provada por asserção, não por argumento.

---
