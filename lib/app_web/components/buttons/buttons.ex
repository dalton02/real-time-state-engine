defmodule AppWeb.Components.ButtonsDS do
  use Phoenix.Component

  attr :url, :string, required: true
  attr :label, :string, required: true

  def go_back(assigns) do
    ~H"""
    <.link
      navigate={@url}
      class="text-[10px] tracking-[0.15em] uppercase
             text-[#5a6a7a] hover:text-[#8a9aaa] transition-colors duration-150"
    >
      {@label}
    </.link>
    """
  end

  attr :label, :string, required: true
  attr :disable_with, :string, required: true

  def submit(assigns) do
    ~H"""
    <button
      type="submit"
      phx-disable-with={@disable_with}
      class="bg-orange-500 text-black cursor-pointer text-[11px]
                   font-semibold tracking-[0.2em] uppercase px-6 py-2.5
                   hover:bg-orange-400 active:scale-[0.99]
                   transition-all duration-150 disabled:bg-[#7c3a12]
                   disabled:text-[#555] disabled:cursor-not-allowed"
    >
      {@label}
    </button>
    """
  end
end
