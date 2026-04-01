defmodule App.Telemetry.NodeTest do
  use App.DataCase

  alias App.Telemetry.Node

  describe "changeset/2" do
    test "valid params produce valid changeset" do
      params = %{
        machine_identifier: "node-123",
        location: "Sector B"
      }

      changeset = Node.changeset(%Node{}, params)

      assert changeset.valid?
    end

    test "missing machine_identifier is invalid" do
      params = %{
        location: "Sector B"
      }

      changeset = Node.changeset(%Node{}, params)

      refute changeset.valid?
    end

    test "missing location is invalid" do
      params = %{
        machine_identifier: "node-123"
      }

      changeset = Node.changeset(%Node{}, params)

      refute changeset.valid?
    end
  end
end
