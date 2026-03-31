defmodule App.Telemetry.NodeMetrics do
  use Ecto.Schema
  import Ecto.Changeset

  schema "node_metrics" do
    belongs_to :node, App.Telemetry.Node
    field :status, :string
    field :total_events_processed, :integer
    field :last_payload, :map
    field :last_seen_at, :utc_datetime_usec
  end

  def changeset(node_metrics, params \\ %{}) do
    node_metrics
    |> cast(params, [:node_id, :status, :total_events_processed, :last_payload, :last_seen_at])
    |> validate_required([:node_id, :status])
    |> unique_constraint(:node_id)
  end
end
