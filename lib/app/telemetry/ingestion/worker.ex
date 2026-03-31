defmodule App.Telemetry.Ingestion.Worker do
  use GenServer

  @impl true
  def init(:ok) do
    schedule_sweep()
    {:ok, nil}
  end

  def start_link(_args) do
    IO.puts("Starting Telemetry Worker")
    GenServer.start_link(__MODULE__, :ok, name: :telemetry_worker)
  end

  def schedule_sweep do
    if Mix.env() != :test do
      Process.send_after(self(), :sweep, 5000)
    end
  end

  def do_sweep() do
    list = :ets.tab2list(:w_core_telemetry_cache)
    IO.puts("Sweeping")

    Enum.each(list, fn {node_id, status, event_count, last_payload, timestamp} ->
      App.Telemetry.persist_node_metrics({node_id, status, event_count, last_payload, timestamp})
    end)
  end

  @impl true
  def handle_info(:sweep, state) do
    do_sweep()
    schedule_sweep()
    {:noreply, state}
  end
end
