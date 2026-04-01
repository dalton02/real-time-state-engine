defmodule App.Telemetry.IngestionTest do
  alias App.Telemetry
  alias App.Telemetry.NodeMetrics
  alias App.Telemetry.Ingestion.Worker
  alias App.Telemetry.Ingestion.Server
  alias App.Telemetry.Ingestion.Supervisor

  use App.DataCase

  @metric_example %{
    node_id: 1,
    status: "operational",
    event_count: 1,
    last_payload: %{
      thermal_power_mw: 3415.6,
      electrical_power_mw: 1250.3,
      power_output_percent: 98.7,
      neutron_flux_percent: 94.2
    },
    timestamp: DateTime.utc_now()
  }

  setup_all do
    Supervisor.start_link("")
    {:ok, recipient: :world}
  end

  describe "ETS persistence" do
    setup do
      Server.clear()
      {:ok, recipient: :world}
    end

    test "creates a node_metric if do not exist" do
      Server.add_metric(@metric_example)

      data = Server.get_node(1)

      assert {1, @metric_example.status, 1, @metric_example.last_payload,
              @metric_example.timestamp} == elem(data, 1)
    end

    test "correctly update event_count field" do
      total = 400

      for _ <- 1..total do
        Server.add_metric(@metric_example)
      end

      data = Server.get_node(1)

      assert {1, @metric_example.status, total, @metric_example.last_payload,
              @metric_example.timestamp} == elem(data, 1)
    end
  end

  describe "Write Behind Mechanism" do
    setup do
      Telemetry.register_node(%{machine_identifier: "123", location: "Sector B"})
      Server.clear()
      {:ok, recipient: :world}
    end

    test "upsert the node_metrics into DB" do
      Server.add_metric(@metric_example)
      Process.sleep(400)
      Worker.do_sweep()
      nodeDB = Repo.get_by(NodeMetrics, node_id: 1)

      assert {1, @metric_example.status, 1, @metric_example.last_payload,
              @metric_example.timestamp} ==
               {nodeDB.id, nodeDB.status, nodeDB.total_events_processed,
                Map.new(
                  nodeDB.last_payload,
                  fn {k, v} -> {String.to_existing_atom(k), v} end
                ), nodeDB.last_seen_at}
    end
  end
end
