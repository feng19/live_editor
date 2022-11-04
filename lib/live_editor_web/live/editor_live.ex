defmodule LiveEditorWeb.EditorLive do
  @moduledoc false
  use LiveEditorWeb, :editor_live_view
  require Logger
  alias LiveEditor.{ComponentRender, UI}

  def mount(_params, _session, socket) do
    groups = [
      %{name: "Heroicons", components: UI.Heroicons.components()},
      %{name: "Base", components: UI.Base.components()}
    ]

    {:ok,
     assign(socket,
       groups: groups,
       breadcrumbs: ["home", "1", "2"],
       meta_previews: [],
       previews: [],
       select_id: nil,
       select_component: nil,
       code: nil
     )}
  end

  def handle_event("add_component", %{"group" => group, "name" => name} = params, socket) do
    assigns = socket.assigns

    component =
      assigns.groups
      |> Enum.find(&match?(%{name: ^group}, &1))
      |> Map.get(:components)
      |> Enum.find(&match?(%{name: ^name}, &1))
      |> UI.Helper.apply_example_preview()

    # todo set id
    id = "ld-#{System.os_time(:millisecond)}"
    index = Map.get(params, "index", -1)
    meta_previews = List.insert_at(assigns.meta_previews, index, {id, component})
    rendered = render_component(component)
    preview = %{rendered: rendered, class: component[:preview_class]}
    previews = List.insert_at(assigns.previews, index, {id, preview})

    socket =
      assign(socket,
        meta_previews: meta_previews,
        previews: previews,
        code: nil,
        select_id: id,
        select_component: component
      )

    {:noreply, socket}
  end

  def handle_event("attr_changed", params, socket) do
    [target] = params["_target"]
    value = params[target]
    component = socket.assigns.select_component
    attrs = component.attrs
    attr = List.keyfind(attrs, target, 0) |> elem(1)
    Logger.info(inspect(attr, label: "old attr"))

    attr =
      case attr.type do
        :boolean ->
          Map.put(attr, :value, value == "on")

        :global ->
          if attr.name == :rest do
            # todo don't use Code.eval_string/1
            rest = Code.eval_string(value) |> elem(0) |> Map.new()

            value =
              if old = attr[:value] do
                Map.new(old) |> Map.merge(rest) |> Map.to_list()
              else
                rest
              end

            Map.put(attr, :value, value)
          else
            attr
          end

        :atom ->
          value = String.to_existing_atom(value)
          Map.put(attr, :value, value)

        :string ->
          Map.put(attr, :value, value)

        _ ->
          attr
      end

    Logger.info(inspect(attr, label: "new attr"))

    socket =
      %{component | attrs: List.keyreplace(attrs, target, 0, {target, attr})}
      |> component_changed(socket)

    {:noreply, socket}
  end

  def handle_event("slot_changed", %{"id" => slot_name, "content" => content}, socket) do
    component = socket.assigns.select_component
    slots = component.slots
    slot = List.keyfind(slots, slot_name, 0) |> elem(1) |> Map.put(:value, content)

    socket =
      %{component | slots: List.keyreplace(slots, slot_name, 0, {slot_name, slot})}
      |> component_changed(socket)

    {:noreply, socket}
  end

  def handle_event("select_component", %{"id" => id}, socket) do
    assigns = socket.assigns

    socket =
      if assigns.select_id != id do
        {_, component} = List.keyfind(assigns.meta_previews, id, 0)
        assign(socket, select_id: id, select_component: component)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event(
        "update_sort",
        %{"id" => _id, "old_index" => old_index, "new_index" => new_index},
        socket
      ) do
    assigns = socket.assigns

    socket =
      assign(socket,
        meta_previews: update_sort(assigns.meta_previews, old_index, new_index),
        previews: update_sort(assigns.previews, old_index, new_index)
      )

    {:noreply, socket}
  end

  def handle_event("remove_component", %{"value" => id}, socket) do
    assigns = socket.assigns
    meta_previews = List.keydelete(assigns.meta_previews, id, 0)
    previews = List.keydelete(assigns.previews, id, 0)

    socket =
      if assigns.select_id == id do
        assign(socket, select_id: nil, select_component: nil)
      else
        socket
      end
      |> assign(meta_previews: meta_previews, previews: previews)

    {:noreply, socket}
  end

  def handle_event("show_code", _params, socket) do
    {:noreply, show_code(socket)}
  end

  def handle_event("hide_code", _params, socket) do
    {:noreply, assign(socket, code: nil)}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  defp update_sort(list, old_index, new_index) do
    {item, list} = List.pop_at(list, old_index)
    List.insert_at(list, new_index, item)
  end

  defp component_changed(component, socket) do
    %{select_id: curr_id, previews: previews, meta_previews: meta_previews} = socket.assigns
    meta_previews = List.keyreplace(meta_previews, curr_id, 0, {curr_id, component})
    preview = %{rendered: render_component(component), class: component[:preview_class]}
    previews = List.keyreplace(previews, curr_id, 0, {curr_id, preview})

    socket
    |> assign(
      meta_previews: meta_previews,
      previews: previews,
      select_component: component
    )
    |> code_changed()
  end

  defp render_component(component) do
    with render when not is_nil(render) <- component[:render],
         true <- is_function(render, 1) do
      render.(component)
    else
      _ -> ComponentRender.render(component)
    end
  end

  defp code_changed(socket) do
    if socket.assigns.code do
      show_code(socket)
    else
      socket
    end
  end

  defp show_code(socket) do
    code = LiveEditor.CodeRender.render_heex(socket.assigns.select_component)
    assign(socket, code: code)
  end
end
