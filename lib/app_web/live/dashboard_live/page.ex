
defmodule AppWeb.DashboardLive.PageLive do
  use AppWeb, :live_view

  alias App.Telemetry

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    nodes = Telemetry.list_nodes()

    {:ok, socket |> assign(nodes: nodes,user: user.email)}
  end

  def handle_event("teste",_params,socket) do
    { :noreply, socket |> assign(nodes: socket.assigns.nodes,user: "mudou") }
  end
end
