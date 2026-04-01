defmodule App.Telemetry.Node do
  use Ecto.Schema
  import Ecto.Changeset

  schema "nodes" do
    field :machine_identifier, :string
    field :location, :string
    has_one :node_metrics, App.Telemetry.NodeMetrics, foreign_key: :node_id
    timestamps()
  end

  def changeset(node, params \\ %{}) do
    node
    |> cast(params, [:machine_identifier, :location])
    |> validate_required([:machine_identifier, :location])
    |> unique_constraint([:machine_identifier])
  end
end
