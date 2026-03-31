defmodule App.Repo.Migrations.CreateTelemetryTables do
  use Ecto.Migration

  def change do
    create table(:nodes) do
      add :machine_identifier, :string, null: false
      add :location, :string, null: false
    end

    create unique_index(:nodes, [:machine_identifier])

    create table(:node_metrics) do
      add :node_id, references(:nodes, on_delete: :delete_all), null: false
      add :status, :string, null: false
      add :total_events_processed, :integer, default: 0
      add :last_payload, :map
      add :last_seen_at, :utc_datetime_usec
    end

    create unique_index(:node_metrics, [:node_id])
  end
end
