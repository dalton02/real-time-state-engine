defmodule App.Telemetry.Ingestion.Supervisor do
  use Supervisor

  def start_link(_arg) do
    IO.puts("Starting Telemetry Supervisor")
    Supervisor.start_link(__MODULE__, :ok, name: :telemetry_supervisor)
  end

  def init(_arg) do
    children = [
      App.Telemetry.Ingestion.Server,
      App.Telemetry.Ingestion.Worker
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
