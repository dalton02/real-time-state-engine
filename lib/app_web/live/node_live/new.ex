defmodule AppWeb.NodeLive.New do
  use AppWeb, :live_view
  alias AppWeb.Components.InputsDS
  alias AppWeb.Components.ButtonsDS
  alias App.Telemetry
  alias App.Telemetry.Node

  def mount(_params, _session, socket) do
    form = to_form(Node.changeset(%Node{}, %{}))
    {:ok, assign(socket, form: form, page_title: "Create Node")}
  end

  def handle_event("validate", %{"node" => params}, socket) do
    form =
      %Node{}
      |> Node.changeset(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"node" => params}, socket) do
    case Telemetry.register_node(params) do
      {:ok, _node} ->
        {:noreply,
         socket
         |> put_flash(:info, "Node registered successfully.")
         |> redirect(to: ~p"/")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
