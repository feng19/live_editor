defmodule LiveEditorWeb.EditorLive do
  @moduledoc false
  use LiveEditorWeb, :editor_live_view
  require Logger
  alias LiveEditorWeb.Bars
  alias LiveEditor.{ComponentRender, CodeRender, UI, Meta}

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
      %{label: "Hero Icons", name: "hero_icons", components: UI.Heroicons.components(), cols: 5}
    ]

    socket =
      assign(socket,
        file_path: nil,
        left_bar_settings: left_bar_settings,
        nav_items: [],
        groups: groups,
        breadcrumbs: [],
        code: nil,
        all_code: nil,
        select_id: nil,
        select_component: nil,
        select_children: [],
        previews: [],
        meta_previews: []
      )
      # todo for test
      |> test_helper()

    {:ok, socket}
  end

  def handle_event("add_component", %{"group" => group, "name" => name} = params, socket) do
    {id, component} = init_component(socket.assigns.groups, group, name)
    index = Map.get(params, "index", -1)

    socket =
      case socket.assigns.select_component do
        %{type: :text} ->
          add_component(:root, id, component, index, socket)

        _ ->
          parent_id = Map.get(params, "to", :root)
          add_component(parent_id, id, component, index, socket)
      end

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
      |> current_component_changed(socket)

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
      |> current_component_changed(socket)

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
      |> current_component_changed(socket)

    {:noreply, socket}
  end

  def handle_event("select_component", %{"id" => id}, socket) do
    assigns = socket.assigns

    socket =
      if assigns.select_id != id do
        component = Meta.find(assigns.meta_previews, id)
        nav_items = assigns.nav_items
        select_children = UI.Helper.find_from_nav_items(nav_items, id) |> Map.fetch!(:children)
        breadcrumbs = calc_breadcrumbs(nav_items, id)

        assign(socket,
          select_id: id,
          select_component: component,
          select_children: select_children,
          breadcrumbs: breadcrumbs
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event(
        "update_sort",
        %{
          "id" => id,
          "from" => from,
          "to" => to,
          "old_index" => old_index,
          "new_index" => new_index
        },
        socket
      ) do
    {from, to, changes} =
      case {from, to} do
        {"root", "root"} ->
          {:root, :root, %{id => :move}}

        {"root", _} ->
          {:root, to, %{to => :rerender}}

        {_, "root"} ->
          {from, :root, %{id => :rerender, from => :rerender}}

        _ ->
          {from, to, %{id => :move, from => :rerender, to => :rerender}}
      end

    socket =
      socket.assigns.meta_previews
      |> Meta.update_sort(id, from, to, old_index, new_index)
      |> then(&meta_changed(socket, &1, changes))

    {:noreply, socket}
  end

  def handle_event(
        "update_sort",
        %{"id" => id, "old_index" => old_index, "new_index" => new_index},
        socket
      ) do
    socket =
      socket.assigns.meta_previews
      |> Meta.update_sort(old_index, new_index)
      |> then(&meta_changed(socket, &1, %{id => :move}))

    {:noreply, socket}
  end

  def handle_event("remove_component", %{"value" => id}, socket) do
    socket =
      socket.assigns.meta_previews
      |> Meta.remove(id)
      |> then(&meta_changed(socket, &1, %{id => :remove}))

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
        "code" ->
          assign(socket, code: code)

        "slot-" <> name ->
          slot_name = String.split(name, "-") |> List.last()
          slot_changed(socket, slot_name, code)
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

  def handle_event("component_text_changed", %{"text" => value}, socket) do
    %{select_id: id, select_component: component} = socket.assigns
    socket = component_changed(%{component | value: value}, id, socket)
    {:noreply, socket}
  end

  def handle_event("save_file", _, socket) do
    socket = save_file(socket)
    {:noreply, socket}
  end

  def handle_event(_event, _params, socket) do
    {:noreply, socket}
  end

  def handle_info({"new_file", file_path}, socket) do
    socket = assign(socket, file_path: file_path)
    {:noreply, socket}
  end

  def handle_info({"open_file", file_path}, socket) do
    socket = open_file(socket, file_path)
    {:noreply, socket}
  end

  def handle_info(info, socket) do
    Logger.info("info: #{inspect(info)}")
    {:noreply, socket}
  end

  defp init_component(groups, group, name) do
    component =
      groups
      |> Enum.find(&match?(%{name: ^group}, &1))
      |> Map.get(:components)
      |> Enum.find(&match?(%{name: ^name}, &1))
      |> UI.Helper.apply_example_preview()
      |> Map.put_new(:children, [])

    now = System.os_time(:millisecond)
    component = append_id_for_children(component, now) |> elem(0)
    {gen_id(now), component}
  end

  defp gen_id(index), do: "ld-#{index}"

  defp append_id_for_children(component, parent_id) do
    {children, index} =
      Enum.map_reduce(component.children, parent_id + 1, fn child, acc ->
        id = gen_id(acc)
        child = Map.put(child, :parent_id, "ld-#{parent_id}")

        if child[:children] do
          {child, acc} = append_id_for_children(child, acc)
          {{id, child}, acc + 1}
        else
          {{id, child}, acc + 1}
        end
      end)

    {%{component | children: children}, index}
  end

  defp add_component(parent_id, id, component, index, socket) do
    meta_previews = Meta.insert_at(socket.assigns.meta_previews, parent_id, index, id, component)

    if parent_id == :root do
      assign(socket, code: nil, select_id: id)
    else
      assign(socket, code: nil)
    end
    |> meta_changed(meta_previews, %{id => :rerender})
  end

  defp current_component_changed(component, socket) do
    component_changed(component, socket.assigns.select_id, socket)
  end

  defp component_changed(component, id, socket) do
    meta_previews = Meta.update(socket.assigns.meta_previews, id, component)

    socket
    |> meta_changed(meta_previews, %{id => :rerender})
    |> maybe_show_code()
  end

  defp components_to_meta(components, id_start) do
    Enum.map_reduce(components, id_start, fn component, id ->
      {children, id} = component |> Map.get(:children, []) |> components_to_meta(id + 1)
      component = Map.put(component, :children, children)
      {{"ld-#{id}", component}, id + 1}
    end)
  end

  defp meta_changed(socket, meta_previews, changes) do
    assigns = socket.assigns
    %{meta_previews: old_meta_previews, previews: old_previews} = assigns

    changes =
      Enum.flat_map(changes, fn
        {id, :remove} ->
          case Meta.find_root_parent_id(old_meta_previews, id) do
            :root -> [{id, :remove}]
            root_parent_id -> [{id, :remove}, {root_parent_id, :rerender}]
          end

        {id, op} ->
          case Meta.find_root_parent_id(meta_previews, id) do
            :root -> [{id, op}]
            root_parent_id -> [{id, op}, {root_parent_id, :rerender}]
          end
      end)
      |> Map.new()

    Enum.reduce_while(meta_previews, [], fn {id, component}, acc ->
      case Map.get(changes, id) do
        :rerender ->
          case component_to_preview(component) do
            error = {:error, _error_msg} -> {:halt, error}
            preview -> {:cont, [{id, preview} | acc]}
          end

        :remove ->
          {:cont, acc}

        _ ->
          old = List.keyfind(old_previews, id, 0)
          {:cont, [old | acc]}
      end
    end)
    |> case do
      {:error, error_msg} ->
        put_flash(socket, :error, error_msg)

      previews ->
        select_id = assigns.select_id

        Enum.reduce(changes, socket, fn {id, op}, acc ->
          if select_id == id do
            case op do
              :remove ->
                assign(acc, code: nil, select_id: nil, select_component: nil)

              :rerender ->
                component = Meta.find(meta_previews, id)
                assign(acc, select_component: component)

              :move ->
                component = Meta.find(meta_previews, id)
                assign(acc, select_component: component)
            end
          else
            if Meta.in_children?(assigns.select_component, id) do
              select_component = Meta.find(meta_previews, select_id)
              assign(acc, select_component: select_component)
            else
              acc
            end
          end
        end)
        |> assign(previews: Enum.reverse(previews))
        |> meta_changed(meta_previews)
    end
  end

  defp meta_changed(socket, meta_previews) do
    nav_items = UI.Helper.calc_nav_items(meta_previews)

    {select_children, breadcrumbs} =
      if select_id = socket.assigns.select_id do
        {
          UI.Helper.find_from_nav_items(nav_items, select_id) |> Map.fetch!(:children),
          calc_breadcrumbs(nav_items, select_id)
        }
      else
        {[], []}
      end

    assign(
      socket,
      select_children: select_children,
      meta_previews: meta_previews,
      nav_items: nav_items,
      breadcrumbs: breadcrumbs
    )
  end

  defp meta_to_previews(meta_previews) do
    Enum.map(meta_previews, fn {id, component} ->
      rendered = render_component!(component)
      preview = %{rendered: rendered, class: component[:preview_class]}
      {id, preview}
    end)
  end

  defp calc_breadcrumbs(nav_items, id) do
    do_calc_breadcrumbs(nav_items, id, []) |> Enum.reverse()
  end

  defp do_calc_breadcrumbs(items, id, breadcrumbs) do
    Enum.reduce_while(items, breadcrumbs, fn
      %{id: ^id, label: label}, acc ->
        {:halt, [label | acc]}

      %{label: label, children: children}, acc ->
        case do_calc_breadcrumbs(children, id, []) do
          [] -> {:cont, acc}
          new -> {:halt, new ++ [label | acc]}
        end
    end)
  end

  defp component_to_preview(component) do
    case render_component(component) do
      error = {:error, _error_msg} -> error
      rendered -> %{rendered: rendered, class: component[:preview_class]}
    end
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

  defp open_file(socket, file_path) do
    components = File.read!(file_path) |> LiveEditor.Parser.parse()
    now = System.os_time(:millisecond)
    meta_previews = components_to_meta(components, now) |> elem(0)
    previews = meta_to_previews(meta_previews)

    socket
    |> assign(previews: previews, file_path: file_path)
    |> meta_changed(meta_previews)
  rescue
    reason ->
      error_msg = Exception.format(:error, reason, __STACKTRACE__)
      Logger.error(error_msg)
      put_flash(socket, :error, "open file failed, go back to console and see details.")
  catch
    error, reason ->
      error_msg = Exception.format(error, reason, __STACKTRACE__)
      Logger.error(error_msg)
      put_flash(socket, :error, "open file failed, go back to console and see details.")
  end

  defp save_file(socket) do
    %{file_path: file_path, meta_previews: meta_previews} = socket.assigns
    content = LiveEditor.Parser.to_string(meta_previews)
    File.write!(file_path, content)
    put_flash(socket, :info, "Save finished.")
  rescue
    reason ->
      error_msg = Exception.format(:error, reason, __STACKTRACE__)
      Logger.error(error_msg)
      put_flash(socket, :error, "save file failed, go back to console and see details.")
  catch
    error, reason ->
      error_msg = Exception.format(error, reason, __STACKTRACE__)
      Logger.error(error_msg)
      put_flash(socket, :error, "save file failed, go back to console and see details.")
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
    |> current_component_changed(socket)
  end

  defp test_helper(socket) do
    #    groups = socket.assigns.groups
    #    div = init_component(groups, "base", "div")
    #    socket = add_component(div, "ld-first-div", -1, socket)
    #    modal = init_component(groups, "core", "modal")
    #    socket = add_component(modal, "ld-first-modal", -1, socket)
    #    icon = init_component(groups, "hero_icons", "academic_cap")
    #    add_component(icon, "ld-first-icon", -1, socket)
    socket
  end
end
