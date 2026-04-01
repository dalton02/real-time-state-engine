defmodule AppWeb.DashboardLive.PageLive do
  alias App.Telemetry
  alias AppWeb.Components.Dashboard
  use AppWeb, :live_view

  @topic "telemetry:updates"

  def mount(_params, _session, socket) do
    Phoenix.PubSub.subscribe(App.PubSub, @topic)
    nodes = Telemetry.get_hot_data()

    {:ok,
     assign(socket,
       nodes: nodes
     )}
  end

  def handle_info({:nodes_updated, _node_id}, socket) do
    nodes = Telemetry.get_hot_data()

    {:noreply,
     assign(socket,
       nodes: nodes
     )}
  end
end
