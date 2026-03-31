defmodule App.Telemetry do
  alias App.Telemetry.Node
  alias App.Telemetry.NodeMetrics

  alias App.Telemetry.Ingestion.Server
  alias App.Repo

  @doc "Registers a new node in the system."
  def register_node(params) do
    %Node{} |> Node.changeset(params) |> Repo.insert()
  end

  @doc "Returns a node by machine_identifier or {:error, :not_found}."

  def get_node(machine_identifier) do
    case Repo.get_by(Node, machine_identifier: machine_identifier) do
      nil -> {:error, :not_found}
      node -> {:ok, node}
    end
  end

  @doc "Returns all registered nodes."
  def list_nodes() do
    Repo.all(Node)
  end

  @doc "Return all node metrics in DB"
  def list_node_metrics() do
    Repo.all(NodeMetrics)
  end

  @doc "Ingests an event into the real-time cache asynchronously."
  def ingest_event(params) do
    Server.add_metric(params)
  end

  @doc "Persists the current ETS state of a node into SQLite."
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
