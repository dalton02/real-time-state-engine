defmodule App.Telemetry.Ingestion.Server do
  use GenServer

  @pos_status 2
  @pos_counter 3
  @pos_payload 4
  @pos_timestamp 5

  @impl true
  def init(:ok) do
    table =
      :ets.new(
        :w_core_telemetry_cache,
        [:set, :protected, :named_table, read_concurrency: true]
      )

    App.Telemetry.list_node_and_metrics()
    |> Enum.each(fn node ->
      metrics = node.node_metrics

      ets_entry = {
        node.id,
        (metrics && metrics.status) || nil,
        (metrics && metrics.total_events_processed) || 0,
        (metrics && metrics.last_payload) || %{},
        (metrics && metrics.last_seen_at) || nil
      }

      :ets.insert(:w_core_telemetry_cache, ets_entry)
    end)

    {:ok, table}
  end

  def start_link(_args) do
    IO.puts("Starting Telemetry Ingestion")
    GenServer.start_link(__MODULE__, :ok, name: :telemetry_server)
  end

  @doc "When a new node is created, the node is placed in the ets table"
  def new_node(id) do
    GenServer.cast(:telemetry_server, {:new_node, id})
  end

  @doc "Returns all records currently in the ETS cache."
  def list() do
    GenServer.call(:telemetry_server, :list)
  end

  def clear() do
    GenServer.call(:telemetry_server, :clear)
  end

  @doc "Returns a specific node record by id."
  def get_node(id) do
    GenServer.call(:telemetry_server, {:get_node, id})
  end

  @doc "Adds a metric event to the ETS cache. Fire-and-forget."

  def add_metric(metric) do
    GenServer.cast(:telemetry_server, {:add_metric, metric})
  end

  @impl true
  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(:w_core_telemetry_cache)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    list = :ets.tab2list(:w_core_telemetry_cache)
    {:reply, list, state}
  end

  @impl true
  def handle_call({:get_node, id}, _from, state) do
    case :ets.lookup(:w_core_telemetry_cache, id) do
      [] -> {:reply, {:error, :not_found}, state}
      [record] -> {:reply, {:ok, record}, state}
    end
  end

  @impl true
  def handle_cast({:new_node, id}, state) do
    ets_entry = {
      id,
      nil,
      0,
      %{},
      nil
    }

    :ets.insert(:w_core_telemetry_cache, ets_entry)
    Phoenix.PubSub.broadcast(App.PubSub, "telemetry:updates", {:nodes_updated, id})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:add_metric, metrics}, state) do
    :ets.update_counter(
      :w_core_telemetry_cache,
      metrics.node_id,
      {@pos_counter, 1},
      {metrics.node_id, metrics.status, 0, metrics.last_payload, metrics.timestamp}
    )

    :ets.update_element(:w_core_telemetry_cache, metrics.node_id, [
      {@pos_status, metrics.status},
      {@pos_payload, metrics.last_payload},
      {@pos_timestamp, metrics.timestamp}
    ])

    Phoenix.PubSub.broadcast(App.PubSub, "telemetry:updates", {:nodes_updated, metrics.node_id})

    {:noreply, state}
  end
end
