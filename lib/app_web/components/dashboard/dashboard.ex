defmodule AppWeb.Components.Dashboard do
  use AppWeb, :html
  attr :nodes, :list, default: []

  def header(assigns) do
    assigns =
      assign(assigns,
        online: Enum.count(assigns.nodes, fn {_, s, _, _, _} -> s == "operational" end),
        warning: Enum.count(assigns.nodes, fn {_, s, _, _, _} -> s == "warning" end),
        critical: Enum.count(assigns.nodes, fn {_, s, _, _, _} -> s == "critical" end)
      )

    ~H"""
    <div class="mb-8 px-6 py-4 flex items-end justify-between border-b border-[#1e2530]">
      <div>
        <p class="text-[10px] tracking-[0.2em] uppercase text-orange-500 mb-1">
          W-CORE · REAL-TIME MONITOR
        </p>

        <h1 class="text-2xl font-medium text-[#e8edf2] tracking-tight">
          Node Dashboard
        </h1>

        <p class="mt-1 text-[11px] text-[#5a6a7a]">
          {length(@nodes)} nodes registered
        </p>
      </div>

      <div class="flex flex-col justify-end items-end gap-4">
        <div class="flex items-center gap-4">
          <.status_counter color="green-500" label="online" count={@online} />
          <.status_counter color="amber-400" label="warning" count={@warning} />
          <.status_counter color="red-500" label="critical" count={@critical} />
        </div>

        <.link
          navigate={~p"/nodes/new"}
          class="ml-4 px-4 py-2 text-xs font-medium uppercase tracking-wider bg-orange-500 hover:bg-orange-600 text-white rounded-md transition-colors"
        >
          NEW NODE
        </.link>
      </div>
    </div>
    """
  end

  attr :color, :string, required: true
  attr :label, :string, required: true
  attr :count, :integer, default: 0

  def status_counter(assigns) do
    ~H"""
    <div class="flex items-center gap-1.5 text-[11px] text-[#5a6a7a]">
      <span class={"w-2 h-2 rounded-full bg-#{@color}"}></span>
      {@count} {@label}
    </div>
    """
  end
end
