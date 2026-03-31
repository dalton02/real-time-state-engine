defmodule AppWeb.CardNode do
  use AppWeb, :live_component

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def handle_info({:clear_change, id}, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    {node_id, status, event_count, last_payload, last_seen_at} = assigns.node

    ~H"""
    <div class="relative bg-[#0d1117] border border-[#21262d] rounded-xl overflow-hidden
                hover:border-[#30363d] transition-all duration-200 group">
      <% {accent, badge_bg, badge_border, dot_color, dot_glow, text_color, label} =
        case status do
          "operational" ->
            {"from-emerald-500 to-emerald-600", "bg-emerald-500/5", "border-emerald-500/20",
             "bg-emerald-500", "shadow-[0_0_6px_theme(colors.emerald.500/50)]", "text-emerald-400",
             "OPERATIONAL"}

          "warning" ->
            {"from-amber-400 to-amber-500", "bg-amber-400/5", "border-amber-400/20", "bg-amber-400",
             "shadow-[0_0_6px_theme(colors.amber.400/50)]", "text-amber-400", "WARNING"}

          "critical" ->
            {"from-red-500 to-red-600", "bg-red-500/5", "border-red-500/20", "bg-red-500",
             "shadow-[0_0_6px_theme(colors.red.500/50)]", "text-red-400", "CRITICAL"}

          _ ->
            {"from-zinc-600 to-zinc-700", "bg-zinc-500/5", "border-zinc-500/20", "bg-zinc-500", "",
             "text-zinc-500", "UNKNOWN"}
        end %>

      <div class={"h-0.5 w-full bg-gradient-to-r #{accent}"}></div>

      <div class={"absolute top-0 right-0 w-20 h-20 rounded-full opacity-60 pointer-events-none
                  bg-[radial-gradient(circle_at_top_right,#{String.replace(dot_color,"bg-","")}_0%,transparent_70%)]"}>
      </div>

      <div class="p-4">
        <div class="flex items-start justify-between mb-3.5">
          <div>
            <p class="font-['IBM_Plex_Mono'] text-[9px] tracking-[0.14em] uppercase text-zinc-600 mb-1">
              Node
            </p>
            <p class="font-['IBM_Plex_Mono'] text-[13px] font-semibold text-slate-200">
              {node_id}
            </p>
          </div>

          <div class="flex items-center gap-2">
            <div class={"flex items-center gap-1.5 px-2 py-1 rounded-md border #{badge_bg} #{badge_border}"}>
              <span class={"w-[7px] h-[7px] rounded-full flex-shrink-0 #{dot_color} #{dot_glow} animate-pulse"}>
              </span>
              <span class={"font-['IBM_Plex_Mono'] text-[9px] tracking-[0.14em] font-semibold #{text_color}"}>
                {label}
              </span>
            </div>
            <button class=" text-[10px] px-1">
              Editar Metricas
            </button>
          </div>
        </div>

        <div class="h-px bg-[#21262d] mb-3.5"></div>

        <%!-- Metrics --%>
        <div class="grid grid-cols-2 gap-3 mb-3.5">
          <div>
            <p class="font-['IBM_Plex_Mono'] text-[9px] tracking-[0.12em] uppercase text-zinc-700 mb-1">
              Events
            </p>
            <p class="font-['IBM_Plex_Mono'] text-xl font-semibold text-slate-200 leading-none">
              {event_count}
            </p>
          </div>
          <div>
            <p class="font-['IBM_Plex_Mono'] text-[9px] tracking-[0.12em] uppercase text-zinc-700 mb-1">
              Last seen
            </p>
            <p class="font-['IBM_Plex_Mono'] text-[11px] text-slate-500">
              {if last_seen_at, do: Calendar.strftime(last_seen_at, "%H:%M:%S"), else: "—"}
            </p>
          </div>
        </div>

        <%!-- Payload --%>
        <%= if last_payload && map_size(last_payload) > 0 do %>
          <div class="bg-[#080b0f] border border-[#1c2128] rounded-md px-3 py-2.5">
            <p class="font-['IBM_Plex_Mono'] text-[9px] tracking-[0.12em] uppercase text-zinc-700 mb-2">
              Last payload
            </p>
            <%= for {key, value} <- Enum.take(last_payload, 3) do %>
              <div class="flex items-center justify-between py-0.5">
                <span class="font-['IBM_Plex_Mono'] text-[10px] text-zinc-600 truncate mr-2">
                  {key}
                </span>
                <span class="font-['IBM_Plex_Mono'] text-[10px] text-slate-500 shrink-0">
                  {value}
                </span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
