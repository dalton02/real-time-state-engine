defmodule App.Telemetry.Ingestion.Server do
  use GenServer

  # Client
  def start_link(_args) do
    IO.puts("Starting Telemetry Ingestion")
    GenServer.start_link(__MODULE__, :ok, name: :telemetry_server)
  end

  def list() do
    GenServer.call(:telemetry_server, :list)
  end

  def clear() do
    GenServer.call(:telemetry_server, :clear)
  end

  def get_node(id) do
    GenServer.call(:telemetry_server, {:get_node, %{id: id}})
  end

  def add_metric(metric) do
    GenServer.cast(:telemetry_server, {:add_metric, metric})
  end

  # Server (callbacks)
  @impl true
  def init(:ok) do
    table =
      :ets.new(
        :w_core_telemetry_cache,
        [:set, :protected, :named_table, read_concurrency: true]
      )

    {:ok, table}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    list = :ets.delete_all_objects(:w_core_telemetry_cache)
    {:reply, list, state}
  end

  @impl true
  def handle_call(:list, _from, state) do
    list = :ets.tab2list(:w_core_telemetry_cache)
    {:reply, list, state}
  end

  @impl true
  def handle_call({:get_node, data}, _from, state) do
    data = :ets.lookup(:w_core_telemetry_cache, data.id)
    {:reply, data, state}
  end

  @impl true
  def handle_cast({:add_metric, metrics}, state) do
    :ets.update_counter(
      :w_core_telemetry_cache,
      metrics.node_id,
      {3, 1},
      {metrics.node_id, metrics.status, 0, metrics.last_payload, metrics.timestamp}
    )

    :ets.update_element(:w_core_telemetry_cache, metrics.node_id, [
      {2, metrics.status},
      {4, metrics.last_payload},
      {5, metrics.timestamp}
    ])

    {:noreply, state}
  end
end
