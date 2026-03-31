defmodule AppWeb.DashboardLive.PageLive do
  use AppWeb, :live_view

  @interval 1000

  def mount(_params, _session, socket) do
    nodes = :ets.tab2list(:w_core_telemetry_cache)
    Process.send_after(self(), :update_nodes, @interval)

    {:ok,
     assign(socket,
       nodes: nodes,
       last_sweep: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
     )}
  end

  def handle_info(:update_nodes, socket) do
    IO.inspect(socket.assigns.nodes)

    nodes =
      socket.assigns.nodes
      |> Enum.map(fn {node_id, status, event_count, last_payload, last_seen_at} ->
        {
          node_id,
          status,
          event_count + 40,
          last_payload,
          DateTime.utc_now()
        }
      end)

    Process.send_after(self(), :update_nodes, @interval)

    {:noreply,
     assign(socket,
       nodes: nodes,
       last_sweep: Calendar.strftime(DateTime.utc_now(), "%H:%M:%S")
     )}
  end
end
