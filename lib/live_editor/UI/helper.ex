defmodule LiveEditor.UI.Helper do
  @moduledoc false
  alias Phoenix.LiveView.{Diff, Socket}

  def render_component(endpoint, component, assigns) when is_atom(component) do
    socket = %Socket{endpoint: endpoint}

    assigns =
      Map.new(assigns)
      |> Map.put_new(:__changed__, %{})

    # TODO: Make the ID required once we support only stateful module components as live_component
    mount_assigns = if assigns[:id], do: %{myself: %Phoenix.LiveComponent.CID{cid: -1}}, else: %{}

    socket
    |> Diff.component_to_rendered(component, assigns, mount_assigns)
    |> rendered_to_diff_string(socket)
  end

  def render_component(endpoint, {module, function}, assigns) do
    socket = %Socket{endpoint: endpoint}

    assigns
    |> Map.new()
    |> Map.put_new(:__changed__, %{})
    |> then(&apply(module, function, [&1]))
    |> rendered_to_diff_string(socket)
  end

  defp rendered_to_diff_string(rendered, socket) do
    {_, diff, _} = Diff.render(socket, rendered, Diff.new_components())
    diff |> Diff.to_iodata() |> IO.iodata_to_binary() |> Phoenix.HTML.raw()
  end
end
