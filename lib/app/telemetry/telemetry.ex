defmodule App.Telemetry do
  alias App.Telemetry.Node
  alias App.Telemetry.NodeMetrics
  alias App.Repo

  def register_node(params) do
    %Node{} |> Node.changeset(params) |> Repo.insert()
  end

  def get_node(machine_identifier) do
    Repo.get_by(Node, machine_identifier: machine_identifier)
  end

  def list_nodes() do
    Repo.all(Node)
  end

  def upsert_node_metrics(params) do
    %NodeMetrics{}
    |> NodeMetrics.changeset(params)
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: :node_id
    )
  end
end
