defmodule LiveEditorWeb.EditorLive do
  @moduledoc false
  use LiveEditorWeb, :editor_live_view

  require Logger

  def mount(_params, _session, socket) do
    components = 1..50

    {:ok,
     assign(socket,
       components: components,
       breadcrumbs: ["home", "1", "2"],
       attrs: 1..100
     )}
  end

  def handle_event("add_component", params, socket) do
    Logger.info("got add_component, params: #{inspect(params)}")
    {:noreply, socket}
  end

  def handle_event(event, params, socket) do
    Logger.info("got event: #{event}, params: #{inspect(params)}")
    {:noreply, socket}
  end
end
