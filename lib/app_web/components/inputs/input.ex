defmodule AppWeb.Components.InputsDS do
  use Phoenix.Component
  import AppWeb.CoreComponents, only: [translate_error: 1]

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: ""

  def input(assigns) do
    ~H"""
    <div class="mb-8">
      <label class="block text-[10px] tracking-[0.15em] uppercase text-[#8a9aaa] mb-2">
        {@label}
      </label>

      <input
        type={@type}
        name={@field.name}
        value={@field.value}
        placeholder={@placeholder}
        class="w-full bg-[#0a0c0f] border border-[#263040] text-[#e8edf2]
              text-[13px] px-3.5 py-2.5
              focus:outline-none focus:border-orange-500
              focus:shadow-[0_0_0_2px_rgba(249,115,22,0.12)]
              placeholder:text-[#3a4a5a] transition-all duration-150 rounded-none"
      />

      <%= for msg <- @field.errors do %>
        <p class="mt-1.5 text-[10px] text-red-500">
          ✕ {translate_error(msg)}
        </p>
      <% end %>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, default: nil

  def textarea(assigns) do
    ~H"""
    <div class="mb-8">
      <label class="block text-[10px] tracking-[0.15em] uppercase text-[#8a9aaa] mb-2">
        {@label}
      </label>

      <textarea
        name={@field.name}
        rows="6"
        placeholder='{"value": 42.5, "unit": "°C", "timestamp": "2026-04-01T10:00:00Z"}'
        class="w-full bg-[#0a0c0f] border border-[#263040] text-[#e8edf2]
        text-[13px] px-3.5 py-2.5 font-mono
        focus:outline-none focus:border-orange-500
        focus:shadow-[0_0_0_2px_rgba(249,115,22,0.12)]
        placeholder:text-[#3a4a5a] transition-all duration-150 rounded-none resize-y"
      ><%= if @field.value && @field.value != %{} do %><%= Jason.encode!(@field.value, pretty: true) %><% else %>{}<% end %></textarea>

      <p class="mt-1 text-[10px] text-[#5a6a7a]">
        JSON format for the last received payload
      </p>

      <%= if msg = @field.errors |> List.first() do %>
        <p class="mt-1.5 text-[10px] text-red-500">
          ✕ {translate_error(msg)}
        </p>
      <% end %>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true

  def select(assigns) do
    ~H"""
    <div class="mb-6">
      <label class="block text-[10px] tracking-[0.15em] uppercase text-[#8a9aaa] mb-2">
        {@label}
      </label>

      <select
        name={@field.name}
        class="w-full bg-[#0a0c0f] border border-[#263040] text-[#e8edf2]
               text-[13px] px-3.5 py-2.5
               focus:outline-none focus:border-orange-500
               focus:shadow-[0_0_0_2px_rgba(249,115,22,0.12)]
               transition-all duration-150 rounded-none"
      >
        <option value="">Select...</option>

        <%= for option <- @options do %>
          <option
            value={option.value}
            selected={@field.value == option.value}
          >
            {option.label}
          </option>
        <% end %>
      </select>

      <%= if msg = @field.errors |> List.first() do %>
        <p class="mt-1.5 text-[10px] text-red-500">
          ✕ {translate_error(msg)}
        </p>
      <% end %>
    </div>
    """
  end
end
