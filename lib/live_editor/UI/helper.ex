defmodule LiveEditor.UI.Helper do
  @moduledoc false

  def trans_attrs(attrs) do
    Enum.map(attrs, fn attr ->
      attr = Map.drop(attr, [:line]) |> Map.put_new(:value, nil)
      {to_string(attr.name), attr}
    end)
  end

  def trans_slots(slots) do
    Enum.map(slots, fn slot ->
      slot = Map.drop(slot, [:line]) |> Map.put_new(:value, nil)
      {to_string(slot.name), slot}
    end)
  end

  def apply_example_preview(%{example_preview: nil} = component), do: component

  def apply_example_preview(
        %{attrs: attrs, slots: slots, example_preview: example_preview} = component
      ) do
    %{
      component
      | attrs: do_apply_example_preview(example_preview[:attrs], attrs),
        slots: do_apply_example_preview(example_preview[:slots], slots)
    }
    |> Map.put(:children, Map.get(example_preview, :children, []))
    |> Map.put(:assigns, Map.get(example_preview, :assigns, %{}))
    |> Map.put(:let, Map.get(example_preview, :let))
    |> Map.drop([:menu_button, :example_preview])
  end

  def apply_example_preview(component), do: component

  defp do_apply_example_preview(nil, list), do: list
  defp do_apply_example_preview([], list), do: list

  defp do_apply_example_preview(applies, list) do
    Enum.reduce(applies, list, fn {key, value}, acc ->
      key =
        if is_atom(key) do
          to_string(key)
        else
          key
        end

      if {_, map} = List.keyfind(acc, key, 0) do
        List.keyreplace(acc, key, 0, {key, Map.put(map, :value, value)})
      else
        acc
      end
    end)
  end

  def calc_nav_items(items) do
    Enum.map(items, fn {id, component} ->
      children = component |> Map.get(:children, []) |> calc_nav_items()

      {label, _draggable} =
        case component[:type] do
          :text -> {"text", false}
          _ -> {component.name, true}
        end

      %{id: id, label: label, draggable: true, children: children}
    end)
  end

  def find_from_nav_items(nav_items, id) do
    Enum.find_value(nav_items, fn
      c = %{id: ^id} -> c
      %{children: children} -> find_from_nav_items(children, id)
    end)
  end
end
