defmodule App.Telemetry.NodeMetricsTest do
  use App.DataCase

  alias App.Telemetry.NodeMetrics

  describe "changeset/2" do
    test "valid params produce valid changeset" do
      params = %{
        node_id: 1,
        status: "operational",
        total_events_processed: 10,
        last_payload: %{power: 100},
        last_seen_at: DateTime.utc_now()
      }

      changeset = NodeMetrics.changeset(%NodeMetrics{}, params)

      assert changeset.valid?
    end

    test "missing node_id is invalid" do
      params = %{
        status: "operational",
        total_events_processed: 10
      }

      changeset = NodeMetrics.changeset(%NodeMetrics{}, params)

      refute changeset.valid?
      assert %{node_id: ["can't be blank"]} = errors_on(changeset)
    end
  end
end
