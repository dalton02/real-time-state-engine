defmodule App.Telemetry do
  alias App.Telemetry.Node
  alias App.Telemetry.NodeMetrics

  alias App.Telemetry.Ingestion.Server
  alias App.Repo

  def register_node(params) do
    %Node{} |> Node.changeset(params) |> Repo.insert()
  end

  def get_node(machine_identifier) do
    case Repo.get_by(Node, machine_identifier: machine_identifier) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  def list_nodes() do
    Repo.all(Node)
  end

  def ingest_event(params) do
    Server.add_metric(params)
  end

  def persist_node_metrics({node_id, status, event_count, last_payload, timestamp}) do
    changeset =
      NodeMetrics.changeset(%NodeMetrics{}, %{
        node_id: node_id,
        status: status,
        total_events_processed: event_count,
        last_payload: last_payload,
        last_seen_at: timestamp
      })

    Repo.insert(changeset,
      on_conflict: [
        set: [
          status: status,
          total_events_processed: event_count,
          last_payload: last_payload,
          last_seen_at: timestamp
        ]
      ]
    )
  end
end
