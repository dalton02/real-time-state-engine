defmodule App.TelemetryTest do
  use App.DataCase

  alias App.Telemetry

  describe "register nodes" do
    test "creates a node with valid params" do
      params = %{machine_identifier: "AA-01", location: "Setor B"}

      assert {:ok, node} = Telemetry.register_node(params)
      assert node.machine_identifier == "AA-01"
      assert node.location == "Setor B"
    end

    test "fails with duplicate machine identifiers" do
      params = %{machine_identifier: "AA-01", location: "Setor B"}

      {:ok, _} = Telemetry.register_node(params)

      assert {:error, changeset} = Telemetry.register_node(params)
      assert %{machine_identifier: ["has already been taken"]} = errors_on(changeset)
    end

    test "fails without required fields" do
      assert {:error, changeset} = Telemetry.register_node(%{})
      assert %{machine_identifier: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "list nodes" do
    test "returns empty list when no nodes exist" do
      assert Telemetry.list_nodes() == []
    end

    test "returns all registered nodes" do
      {:ok, _} = Telemetry.register_node(%{machine_identifier: "AA-01", location: "Setor A"})
      {:ok, _} = Telemetry.register_node(%{machine_identifier: "AA-02", location: "Setor B"})

      assert length(Telemetry.list_nodes()) == 2
    end
  end

  describe "get node" do
    test "returns node when found" do
      Telemetry.register_node(%{machine_identifier: "AA-01", location: "Setor A"})

      case Telemetry.get_node(1) do
        {:error, _} -> flunk("node not found")
        {:ok, node} -> assert node.machine_identifier == "AA-01"
      end
    end

    test "returns nil when not found" do
      case Telemetry.get_node(-1) do
        {:error, _} -> assert true
        {:ok, _} -> flunk("How is this possible?")
      end
    end
  end
end
