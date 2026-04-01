## O que foi feito nesta etapa

Das implementações desta terceira etapa:

- Dashboard em tempo real lendo dados quentes do ETS via Phoenix.PubSub
- Página de criação de nodes com validação reativa via `phx-change`
- Página de edição de status e payload de nodes
- Design System industrial consistente em todos os componentes HEEx

---

## Arquitetura da camada web

```
Sensor manda evento
        ↓
Server.add_metric()  →  atualiza ETS
        ↓
PubSub.broadcast("telemetry:updates", {:nodes_updated, node_id})
        ↓
DashboardLive recebe handle_info/2
        ↓
lê todo o ETS atualizado
        ↓
assign() →  Phoenix calcula diff do HTML
        ↓
só os cards que mudaram são re-renderizados no browser
```

---

## As páginas implementadas

### Dashboard — `DashboardLive.PageLive`

Ponto central do sistema. Monta com o estado atual do ETS e se mantém
atualizado via PubSub. Qualquer evento que o Server processar resulta em
atualização automática na tela sem reload.

```elixir
def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(App.PubSub, @topic)
    nodes = Telemetry.get_hot_data()
    {:ok,assign(socket,nodes: nodes)}
end

def handle_info({:nodes_updated, _node_id}, socket) do
    nodes = Telemetry.get_hot_data()
    {:noreply,assign(socket,nodes: nodes)}
end
```

### Criação de node — `NodeLive.New`

Formulário com validação reativa via `phx-change="validate"`. Erros
aparecem enquanto o usuário digita sem nenhum request HTTP — o changeset
valida no servidor e o LiveView atualiza só o campo com erro.

### Edição de node — `NodeLive.Edit`

Permite atualizar status e payload de um node. Após salvar, o node
atualizado aparece imediatamente no dashboard via PubSub — a edição
prova que o ciclo completo está funcionando em tempo real.

---

## Design System

Para manter consistência visual e evitar duplicação de markup HEEx, os elementos de interface foram organizados em um pequeno Design System de componentes reutilizáveis.

Os componentes vivem dentro de app_web/components e são agrupados por tipo de elemento de UI.

```
app_web/components
├─ buttons/
│  └─ buttons.ex
├─ inputs/
│  └─ inputs.ex
├─ cards/
│  └─ node.ex
└─ dashboard/
   └─ dashboard.ex
```

### Buttons

Contém botões reutilizáveis usados em formulários e navegação.
Centralizar os botões permite padronizar estilos Tailwind e comportamento
(hover, tracking, uppercase, etc.) sem repetir classes em várias páginas.

Exemplo de uso:

```
<ButtonsDS.submit disable_with="Registering..." label="Register Node" />
```

### Inputs

Inputs, textareas e selects foram agrupados em um módulo único de
componentes de formulário. Isso evita repetição de markup de label,
estilo de erro e layout de campos.

Exemplo de uso:

```
<InputsDS.input  field={@form[:location]} label="Location"
  placeholder="e.g. Sector A - Turbine Hall"/>
```

### Cards

Cards também são componentes visuais reutilizáveis que exibem registros de nodes. Utilizando <.live_component> com IDs únicos, o LiveView aplica diffing automático: apenas os cards cujos dados foram efetivamente alterados são re-renderizados no DOM, otimizando o desempenho em listas dinâmicas.

Exemplo de uso:

```
<.live_component module={AppWeb.CardNode} id={"node-#{node_id}"} node={node} />
```

## Como o PubSub foi implementado

O Server publica no tópico `"telemetry:updates"` após cada atualização do ETS:

```elixir
Phoenix.PubSub.broadcast(
  App.PubSub,
  "telemetry:updates",
  {:nodes_updated, metrics.node_id}
)
```

O Dashboard se inscreve no mount e reage no `handle_info` apresentado anteriormente.

---

## Como os gargalos no PubSub foram evitados

### 1. O broadcast não carrega dados

A mensagem publicada contém apenas o `node_id` — não o payload completo
do evento. Se 50 usuários estiverem com o dashboard aberto e um sensor
mandar um pulso, o PubSub trafega 50 mensagens leves `{:nodes_updated, id}`
em vez de 50 cópias do payload completo.

```elixir
broadcast("telemetry:updates", {:nodes_updated, node_id})
```

### 2. A leitura vem do ETS, não do banco

Quando o `handle_info` dispara, o LiveView lê o ETS indiretamente através da função Telemetry.get_hot_data() que foi abstraida para ler o `:ets.tab2list/1`. Se a
leitura fosse ao SQLite a cada evento, ficaria extremamente sobre carregado.

```
PubSub notifica → LiveView lê ETS (μs) → re-renderiza diff
                                ↑
                    nunca vai ao banco nesse fluxo
```

### 3. Phoenix só re-renderiza o diff

O `assign(socket, nodes: nodes)` não re-renderiza o HTML inteiro —
o Phoenix compara o estado anterior com o novo e envia pelo WebSocket
apenas os fragmentos que mudaram. Se 8 nodes estão no dashboard e só
1 recebeu um evento, os outros 7 cards não são tocados.

---

## Trade-off documentado — `tab2list` vs lookup pontual

A implementação atual relê todo o ETS a cada evento:

```elixir
def handle_info({:nodes_updated, _node_id}, socket) do
  nodes = :ets.tab2list(:w_core_telemetry_cache)   # lê tudo
  {:noreply, assign(socket, nodes: nodes)}
end
```

A alternativa seria atualizar só o node que mudou:

```elixir
def handle_info({:nodes_updated, node_id}, socket) do
  case :ets.lookup(:w_core_telemetry_cache, node_id) do
    [updated] ->
      nodes = Enum.map(socket.assigns.nodes, fn {id, _, _, _, _} = n ->
        if id == node_id, do: updated, else: n
      end)
      {:noreply, assign(socket, nodes: nodes)}
    [] ->
      {:noreply, socket}
  end
end
```

Para o contexto atual — dezenas de nodes numa planta industrial — o
`tab2list` é aceitável e mais simples. A otimização pontual faria
diferença real apenas com milhares de nodes simultâneos, cenário fora
do escopo deste sistema edge.

---

## Arquitetura atualizada

```
┌─────────────────────────────────────────────────────────┐
│                      app_web/                            │
│                                                          │
│   DashboardLive.PageLive  <──── PubSub "telemetry:updates"
│   NodeLive.New                                           │
│   NodeLive.Edit                                          │
│                                                          │
│   lê ETS diretamente no handle_info                      │
│   chama App.Telemetry para escritas                      │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────┐
│                  App.Telemetry                           │
│                                                          │
│   register_node/1                                        │
│   list_nodes/0                                           │
│   get_hot_data/0       ->  Pega dados do ETS             │
│   get_node/1                                             │
│   ingest_event/1      ->  Server → ETS + PubSub.broadcast│
│   persist_node_metrics/1  <── chamado pelo Worker        │
└───────────────────┬─────────────────────────────────────┘
                    │
          ┌─────────┴──────────┐
          ▼                    ▼
┌─────────────────┐  ┌────────────────────────────────────┐
│  SQLite (Ecto)  │  │   App.Telemetry.Ingestion           │
│                 │  │                                     │
│  nodes          │  │   Supervisor (:rest_for_one)        │
│  node_metrics   │  │   ├── Server → ETS + PubSub        │
│                 │  │   └── Worker → Write-Behind         │
└─────────────────┘  └────────────────────────────────────┘
```
