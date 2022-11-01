defmodule LiveEditorWeb.EditorLive do
  @moduledoc false
  use LiveEditorWeb, :editor_live_view
  require Logger
  import LiveEditor.UI.Helper
  alias LiveEditor.UI
  @endpoint LiveEditorWeb.Endpoint

  def mount(_params, _session, socket) do
    groups = [
      %{name: "Heroicons", components: UI.Heroicons.components(@endpoint)},
      %{name: "Base", components: UI.Base.components(@endpoint)}
    ]

    {:ok,
     assign(socket,
       groups: groups,
       breadcrumbs: ["home", "1", "2"],
       meta_previews: [],
       previews: [],
       select_id: "",
       attrs: [],
       slots: []
     )}
  end

  def handle_event("add_component", %{"group" => group, "name" => name} = params, socket) do
    assigns = socket.assigns

    component =
      assigns.groups
      |> Enum.find(&match?(%{name: ^group}, &1))
      |> Map.get(:components)
      |> Enum.find(&match?(%{name: ^name}, &1))

    # todo set id
    id = "ld-#{System.os_time(:millisecond)}"

    index = Map.get(params, "index", -1)
    component_assigns = component.assigns
    component = Map.put(component, :assigns, component_assigns)
    Logger.info(inspect(component, label: "component"))

    meta_previews = List.insert_at(assigns.meta_previews, index, {id, component})

    preview = render_component(component, component_assigns)
    previews = List.insert_at(assigns.previews, index, {id, preview})
    attrs = apply_component_assigns_for_attrs(component.attrs, component_assigns)

    socket =
      assign(socket,
        meta_previews: meta_previews,
        previews: previews,
        select_id: id,
        select_component: component,
        attrs: attrs,
        slots: component.slots
      )

    {:noreply, socket}
  end

  def handle_event("attr_changed", params, socket) do
    [target] = params["_target"]
    value = params[target]
    attr_name = String.to_existing_atom(target)
    assigns = socket.assigns
    curr_id = assigns.select_id
    meta_previews = assigns.meta_previews
    component = assigns.select_component
    # Logger.info(inspect(component, label: "component"))

    attrs = component.attrs
    attr_index = Enum.find_index(attrs, &match?(%{name: ^attr_name}, &1))
    attr = Enum.at(attrs, attr_index)
    component_assigns = component.assigns
    Logger.info(inspect(component_assigns, label: "old component_assigns"))

    component_assigns =
      case attr.type do
        :boolean ->
          Keyword.put(component_assigns, attr_name, value == "on")

        :global ->
          if attr.name == :rest do
            # todo don't use Code.eval_string/1
            rest = Code.eval_string(value) |> elem(0) |> Map.new()
            component_assigns |> Map.new() |> Map.merge(rest) |> Map.to_list()
          else
            component_assigns
          end

        :atom ->
          value = String.to_existing_atom(value)
          Keyword.put(component_assigns, attr_name, value)

        :string ->
          Keyword.put(component_assigns, attr_name, value)

        _ ->
          component_assigns
      end

    Logger.info(inspect(component_assigns, label: "new component_assigns"))

    attrs =
      List.replace_at(attrs, attr_index, attr)
      |> apply_component_assigns_for_attrs(component_assigns)
    Logger.info(inspect(attrs, label: "new attrs"))

    component = %{component | assigns: component_assigns}
    meta_previews = List.keyreplace(meta_previews, curr_id, 0, {curr_id, component})
    preview = render_component(component, component_assigns)
    previews = List.keyreplace(assigns.previews, curr_id, 0, {curr_id, preview})

    socket =
      assign(socket,
        meta_previews: meta_previews,
        previews: previews,
        select_component: component,
        attrs: attrs
      )

    {:noreply, socket}
  end

  def handle_event("select_component", %{"id" => id}, socket) do
    assigns = socket.assigns
    meta_previews = assigns.meta_previews
    {_, component} = List.keyfind(meta_previews, id, 0)
    attrs = apply_component_assigns_for_attrs(component.attrs, component.assigns)

    socket =
      if assigns.select_id != id do
        assign(socket,
          select_id: id,
          select_component: component,
          attrs: attrs,
          slots: component.slots
        )
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
        assign(socket, select_id: "", attrs: [], slots: [])
      else
        socket
      end
      |> assign(meta_previews: meta_previews, previews: previews)

    {:noreply, socket}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  defp update_sort(list, old_index, new_index) do
    {item, list} = List.pop_at(list, old_index)
    List.insert_at(list, new_index, item)
  end

  defp apply_component_assigns_for_attrs(attrs, component_assigns) do
    if index = Enum.find_index(attrs, &match?(%{type: :global, name: :rest}, &1)) do
      {rest, attrs} = List.pop_at(attrs, index)

      {attrs, component_assigns} =
        Enum.map_reduce(attrs, component_assigns, fn attr, acc ->
          name = attr.name

          if a_index = Enum.find_index(acc, &match?({^name, _}, &1)) do
            {{_, value}, acc} = List.pop_at(acc, a_index)
            {Map.put(attr, :value, value), acc}
          else
            {attr, acc}
          end
        end)

      rest_value = inspect(component_assigns)
      attrs ++ [Map.put(rest, :value, rest_value)]
    else
      {attrs, _} =
        Enum.map_reduce(attrs, component_assigns, fn attr, acc ->
          name = attr.name

          if a_index = Enum.find_index(acc, &match?({^name, _}, &1)) do
            {{_, value}, acc} = List.pop_at(acc, a_index)
            {Map.put(attr, :value, value), acc}
          else
            {attr, acc}
          end
        end)

      attrs
    end
  end

  defp render_component(component, assigns) do
    assigns =
      with handler when not is_nil(handler) <- component[:assigns_handler],
           true <- is_function(handler, 1) do
        handler.(assigns)
      else
        _ -> assigns
      end

    with render when not is_nil(render) <- component[:render],
         true <- is_function(render, 3) do
      render.(component, assigns, @endpoint)
    else
      _ -> render_component(@endpoint, {component.module, component.fun_name}, assigns)
    end
  end
end
