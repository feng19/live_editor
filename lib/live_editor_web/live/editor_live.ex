defmodule LiveEditorWeb.EditorLive do
  @moduledoc false
  use LiveEditorWeb, :editor_live_view
  require Logger
  alias LiveEditorWeb.Bars
  alias LiveEditor.{ComponentRender, CodeRender, UI}

  def mount(_params, _session, socket) do
    left_bar_settings = [
      %{label: "Add", name: "add", icon: &Heroicons.squares_plus/1},
      %{label: "Navigator", name: "navigator", icon: &Heroicons.square_3_stack_3d/1}
      # %{label: "Pages", name: "pages", icon: &Heroicons.document/1},
      # %{label: "Template", name: "template", icon: &Heroicons.cube_transparent/1}
    ]

    groups = [
      %{label: "Base", name: "base", components: UI.Base.components()},
      %{label: "Core", name: "core", components: UI.Core.components()},
      %{label: "Hero Icons", name: "hero_icons", components: UI.Heroicons.components()}
    ]

    socket =
      assign(socket,
        file_path: nil,
        left_bar_settings: left_bar_settings,
        nav_items: [],
        groups: groups,
        left_panel: nil,
        breadcrumbs: ["home", "1", "2"],
        code: nil,
        all_code: nil,
        select_id: nil,
        select_component: nil,
        previews: [],
        meta_previews: []
      )
      # todo for test
      |> test_helper()

    {:ok, socket}
  end

  def handle_event("add_component", %{"group" => group, "name" => name} = params, socket) do
    component = find_component_from_groups(socket.assigns.groups, group, name)
    # todo set id
    id = "ld-#{System.os_time(:millisecond)}"
    index = Map.get(params, "index", -1)
    socket = add_component(component, id, index, socket)
    {:noreply, socket}
  end

  def handle_event("attr_changed", params, socket) do
    [target | _] = params["_target"]
    value = params[target]
    component = socket.assigns.select_component
    attrs = component.attrs
    attr = List.keyfind(attrs, target, 0) |> elem(1)
    # Logger.info(inspect(attr, label: "old attr"))

    attr =
      case attr.type do
        :boolean ->
          Map.put(attr, :value, value == "on")

        :global ->
          rest = Map.new(value, fn {k, v} -> {String.to_existing_atom(k), v} end)

          value =
            if old = attr[:value] do
              Map.new(old) |> Map.merge(rest)
            else
              rest
            end
            |> Map.to_list()

          Map.put(attr, :value, value)

        :atom ->
          value = String.to_existing_atom(value)
          Map.put(attr, :value, value)

        :string ->
          Map.put(attr, :value, value)

        _ ->
          attr
      end

    # Logger.info(inspect(attr, label: "new attr"))

    socket =
      %{component | attrs: List.keyreplace(attrs, target, 0, {target, attr})}
      |> component_changed(socket)

    {:noreply, socket}
  end

  def handle_event("add_global_attr", %{"k" => ""}, socket), do: {:noreply, socket}

  def handle_event("add_global_attr", %{"k" => key, "v" => v}, socket) do
    component = socket.assigns.select_component
    attrs = component.attrs
    {target, attr} = Enum.find(attrs, &match?({_, %{type: :global}}, &1))
    key = String.to_atom(key)
    value = attr[:value] |> List.wrap() |> Keyword.put(key, v) |> Enum.sort_by(&elem(&1, 0))
    attr = Map.put(attr, :value, value)

    socket =
      %{component | attrs: List.keyreplace(attrs, target, 0, {target, attr})}
      |> component_changed(socket)

    {:noreply, socket}
  end

  def handle_event("remove_global_attr", %{"global-name" => target, "value" => key}, socket) do
    component = socket.assigns.select_component
    attrs = component.attrs
    attr = List.keyfind(attrs, target, 0) |> elem(1)
    key = String.to_existing_atom(key)
    value = Keyword.delete(attr[:value], key)
    attr = Map.put(attr, :value, value)

    socket =
      %{component | attrs: List.keyreplace(attrs, target, 0, {target, attr})}
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
    previews = update_sort(assigns.previews, old_index, new_index)
    meta_previews = update_sort(assigns.meta_previews, old_index, new_index)

    socket =
      socket
      |> assign(previews: previews)
      |> meta_changed(meta_previews)

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
      |> assign(previews: previews)
      |> meta_changed(meta_previews)

    {:noreply, socket}
  end

  def handle_event("show_code", _params, socket) do
    {:noreply, show_code(socket)}
  end

  def handle_event("show_all_code", _params, socket) do
    {:noreply, show_all_code(socket)}
  end

  def handle_event("hide_code", _params, socket) do
    {:noreply, assign(socket, code: nil, all_code: nil)}
  end

  def handle_event("code_changed", %{"id" => id, "code" => code}, socket) do
    socket =
      case id do
        "code" -> assign(socket, code: code)
        "slot-" <> slot_name -> slot_changed(socket, slot_name, code)
      end

    {:noreply, socket}
  end

  def handle_event("format_code", %{"lang" => lang, "code" => code}, socket) do
    code =
      case lang do
        "heex" -> CodeRender.format_heex(code)
        "elixir" -> CodeRender.format_elixir(code)
      end
      |> elem(1)
      |> IO.iodata_to_binary()

    {:reply, %{code: code}, socket}
  end

  def handle_event("switch_left_panel", %{"panel" => panel}, socket) do
    socket =
      case socket.assigns.left_panel do
        ^panel -> assign(socket, left_panel: nil)
        _ -> assign(socket, left_panel: panel)
      end

    {:noreply, socket}
  end

  def handle_event("close_left_panel", _, socket) do
    socket = assign(socket, left_panel: nil)
    {:noreply, socket}
  end

  def handle_event("read_file", %{"file" => file_path}, socket) do
    components = File.read!(file_path) |> LiveEditor.Parser.parse()
    now = System.os_time(:millisecond)
    meta_previews = components_to_meta(components, now)
    previews = meta_to_previews(meta_previews)

    socket =
      socket
      |> assign(previews: previews)
      |> meta_changed(meta_previews)

    {:noreply, socket}
  end

  def handle_event("save_file", _, socket) do
    %{file_path: file_path, meta_previews: meta_previews} = socket.assigns
    content = LiveEditor.Parser.to_string(meta_previews)
    File.write!(file_path, content)
    socket = put_flash(socket, :info, "Save finished.")
    {:noreply, socket}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  defp update_sort(list, old_index, new_index) do
    {item, list} = List.pop_at(list, old_index)
    List.insert_at(list, new_index, item)
  end

  defp find_component_from_groups(groups, group, name) do
    groups
    |> Enum.find(&match?(%{name: ^group}, &1))
    |> Map.get(:components)
    |> Enum.find(&match?(%{name: ^name}, &1))
    |> UI.Helper.apply_example_preview()
  end

  defp add_component(component, id, index, socket) do
    case render_component(component) do
      {:error, error_msg} ->
        put_flash(socket, :error, error_msg)

      rendered ->
        %{previews: previews, meta_previews: meta_previews} = socket.assigns
        meta_previews = List.insert_at(meta_previews, index, {id, component})
        preview = %{rendered: rendered, class: component[:preview_class]}
        previews = List.insert_at(previews, index, {id, preview})

        assign(socket,
          code: nil,
          select_id: id,
          select_component: component,
          previews: previews
        )
        |> meta_changed(meta_previews)
    end
  end

  defp component_changed(component, socket) do
    case render_component(component) do
      {:error, _error_msg} ->
        # put_flash(socket, :error, error_msg)
        socket

      rendered ->
        %{select_id: curr_id, previews: previews, meta_previews: meta_previews} = socket.assigns
        meta_previews = List.keyreplace(meta_previews, curr_id, 0, {curr_id, component})
        preview = %{rendered: rendered, class: component[:preview_class]}
        previews = List.keyreplace(previews, curr_id, 0, {curr_id, preview})

        socket
        |> assign(select_component: component, previews: previews)
        |> meta_changed(meta_previews)
        |> maybe_show_code()
    end
  end

  defp components_to_meta(components, id_start) do
    Enum.map_reduce(components, id_start, fn component, id ->
      {children, id} = component |> Map.get(:children, []) |> components_to_meta(id + 1)
      component = Map.put(component, :children, children)
      {{"ld-#{id}", component}, id + 1}
    end)
  end

  defp meta_changed(socket, meta_previews) do
    assign(
      socket,
      meta_previews: meta_previews,
      nav_items: calc_nav_items(meta_previews)
    )
  end

  defp meta_to_previews(meta_previews) do
    Enum.map(meta_previews, fn {id, component} ->
      rendered = render_component!(component)
      preview = %{rendered: rendered, class: component[:preview_class]}
      {id, preview}
    end)
  end

  defp calc_nav_items(meta_previews) do
    Enum.map(meta_previews, fn {id, component} ->
      children = component |> Map.get(:children, []) |> calc_nav_items()
      %{id: id, label: component.name, children: children}
    end)
  end

  defp render_component!(component) do
    with render when not is_nil(render) <- component[:render],
         true <- is_function(render, 1) do
      render.(component)
    else
      _ -> ComponentRender.render(component)
    end
  end

  defp render_component(component) do
    render_component!(component)
  rescue
    reason ->
      error_msg = Exception.format(:error, reason, __STACKTRACE__)
      Logger.error(error_msg)
      {:error, error_msg}
  catch
    error, reason ->
      error_msg = Exception.format(error, reason, __STACKTRACE__)
      Logger.error(error_msg)
      {:error, error_msg}
  end

  defp maybe_show_code(socket) do
    if socket.assigns.code do
      show_code(socket)
    else
      if socket.assigns.all_code do
        show_all_code(socket)
      else
        socket
      end
    end
  end

  defp show_code(socket) do
    component = socket.assigns.select_component

    code =
      with render when not is_nil(render) <- component[:code_render],
           true <- is_function(render, 1) do
        render.(component)
      else
        _ -> CodeRender.component_string(component)
      end

    assign(socket, code: code)
  end

  defp show_all_code(socket) do
    code = LiveEditor.Parser.to_string(socket.assigns.meta_previews)
    assign(socket, all_code: 1, code: code)
  end

  defp slot_changed(socket, slot_name, content) do
    component = socket.assigns.select_component
    slots = component.slots
    slot = List.keyfind(slots, slot_name, 0) |> elem(1) |> Map.put(:value, content)

    %{component | slots: List.keyreplace(slots, slot_name, 0, {slot_name, slot})}
    |> component_changed(socket)
  end

  defp test_helper(socket) do
    groups = socket.assigns.groups
    div = find_component_from_groups(groups, "base", "div")
    socket = add_component(div, "ld-first-div", -1, socket)
    modal = find_component_from_groups(groups, "core", "modal")
    socket = add_component(modal, "ld-first-modal", -1, socket)
    icon = find_component_from_groups(groups, "hero_icons", "academic_cap")
    add_component(icon, "ld-first-modal", -1, socket)
  end
end
