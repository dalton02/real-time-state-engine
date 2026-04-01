defmodule AppWeb.NodeLive.Edit do
  use AppWeb, :live_view
  alias AppWeb.Components.ButtonsDS
  alias AppWeb.Components.InputsDS

  alias App.Telemetry
  alias App.Telemetry.NodeMetrics

  def bring_form(params) do
    case Jason.decode(params["last_payload"] || "") do
      {:ok, map} ->
        data_form = %{
          last_payload: map,
          status: params["status"]
        }

        form =
          %NodeMetrics{}
          |> NodeMetrics.form(data_form)
          |> Map.put(:action, :validate)
          |> to_form()

        Map.put(form, :params, Map.put(form.params, "last_payload", params["last_payload"]))

      {:error, %Jason.DecodeError{} = error} ->
        changeset =
          %NodeMetrics{}
          |> NodeMetrics.form(%{status: params["status"]})
          |> Ecto.Changeset.add_error(
            :last_payload,
            "Invalid JSON: #{Exception.message(error)}"
          )
          |> Map.put(:action, :validate)

        to_form(changeset)
    end
  end

  @impl true
  def mount(params, _session, socket) do
    case Telemetry.get_node(params["id"]) do
      {:error, _reason} ->
        {:ok, redirect(socket, to: "/")}

      {:ok, data} ->
        IO.inspect(data)

        form =
          to_form(
            NodeMetrics.form(%NodeMetrics{}, %{
              status: (data.node_metrics && data.node_metrics.status) || "",
              last_payload: (data.node_metrics && data.node_metrics.last_payload) || %{}
            })
          )

        IO.inspect(form)
        {:ok, assign(socket, node_id: data.id, form: form)}
    end
  end

  @impl true
  def handle_event("validate", %{"node_metrics" => params}, socket) do
    form = bring_form(params)
    {:noreply, assign(socket, form: form)}
  end

  @impl true
  def handle_event("save", %{"node_metrics" => params}, socket) do
    form = bring_form(params)

    if length(form.errors) != 0 do
      {:noreply, assign(socket, form: form)}
    end

    {:ok, payload} = Jason.decode(params["last_payload"] || "")

    Telemetry.ingest_event(%{
      node_id: socket.assigns.node_id,
      status: params["status"],
      last_payload: payload,
      timestamp: DateTime.utc_now()
    })

    {:noreply, redirect(socket, to: "/")}
  end
end
