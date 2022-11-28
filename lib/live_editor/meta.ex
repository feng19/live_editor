defmodule LiveEditor.Meta do
  @moduledoc false

  def find(list, id) do
    Enum.find_value(list, fn
      {^id, component} -> component
      {_, component} -> component |> Map.get(:children, []) |> find(id)
    end)
  end

  def in_children?(component, child_id) do
    Map.get(component, :children, [])
    |> find(child_id)
    |> case do
      nil -> false
      _ -> true
    end
  end

  def find_root_parent_id(list, id) do
    Enum.find(list, fn
      {^id, _component} ->
        true

      {_, component} ->
        component
        |> Map.get(:children, [])
        |> find_root_parent_id(id)
        |> is_nil()
        |> Kernel.not()
    end)
    |> case do
      {^id, _} -> :root
      {parent_id, _} -> parent_id
      nil -> nil
    end
  end

  def insert_at(list, :root, index, id, component) when is_binary(id) do
    List.insert_at(list, index, {id, component})
  end

  def insert_at(list, parent_id, index, id, component)
      when parent_id != id and is_binary(parent_id) and is_binary(id) do
    update_with(list, parent_id, fn parent ->
      component = Map.put(component, :parent_id, parent_id)
      Map.update(parent, :children, [], &List.insert_at(&1, index, {id, component}))
    end)
  end

  def pop(list, id), do: List.keytake(list, id, 0)

  def remove(list, id) do
    case find(list, id) do
      %{parent_id: parent_id} ->
        update_with(list, parent_id, fn parent ->
          Map.update!(parent, :children, &List.keydelete(&1, id, 0))
        end)

      _component ->
        List.keydelete(list, id, 0)
    end
  end

  def update_with(list, id, fun) do
    find(list, id)
    |> fun.()
    |> then(&update(list, id, &1))
  end

  def update(list, id, component) do
    Enum.reduce_while(list, nil, fn
      {^id, _c}, _acc ->
        {:halt, List.keyreplace(list, id, 0, {id, component})}

      {i, c}, acc ->
        Map.get(c, :children, [])
        |> update(id, component)
        |> case do
          nil ->
            {:cont, acc}

          children ->
            c = Map.put(c, :children, children)
            {:halt, List.keyreplace(list, i, 0, {i, c})}
        end
    end)
  end

  def update_sort(list, old_index, new_index) do
    {item, list} = List.pop_at(list, old_index)
    List.insert_at(list, new_index, item)
  end

  def update_sort(list, id, same_parent, same_parent, old_index, new_index)
      when id != same_parent do
    case same_parent do
      :root ->
        update_sort(list, old_index, new_index)

      parent_id ->
        update_with(list, parent_id, fn parent ->
          Map.update(parent, :children, [], &update_sort(&1, old_index, new_index))
        end)
    end
  end

  def update_sort(list, id, :root, to_parent_id, old_index, new_index)
      when id != to_parent_id and is_binary(to_parent_id) do
    # remove from root
    {{^id, component}, list} = List.pop_at(list, old_index)
    component = Map.put(component, :parent_id, to_parent_id)
    # insert to new parent
    insert_at(list, to_parent_id, new_index, id, component)
  end

  def update_sort(list, id, from_parent_id, :root, old_index, new_index)
      when id != from_parent_id and is_binary(from_parent_id) do
    # remove from old parent
    old_parent = find(list, from_parent_id)
    {{^id, component}, children} = List.pop_at(old_parent.children, old_index)
    component = Map.delete(component, :parent_id)

    update(list, from_parent_id, %{old_parent | children: children})
    # insert to root
    |> List.insert_at(new_index, {id, component})
  end

  def update_sort(list, id, from_parent_id, to_parent_id, old_index, new_index)
      when id != from_parent_id and id != to_parent_id and
             is_binary(from_parent_id) and is_binary(to_parent_id) do
    # remove from old parent
    old_parent = find(list, from_parent_id)
    {{^id, component}, children} = List.pop_at(old_parent.children, old_index)
    component = Map.put(component, :parent_id, to_parent_id)

    update(list, from_parent_id, %{old_parent | children: children})
    # insert to new parent
    |> insert_at(to_parent_id, new_index, id, component)
  end
end
