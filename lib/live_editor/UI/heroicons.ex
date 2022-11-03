defmodule LiveEditor.UI.Heroicons do
  @moduledoc false
  alias LiveEditor.ComponentRender

  def components do
    Heroicons.__components__()
    |> Stream.filter(&match?({_, %{kind: :def}}, &1))
    |> Stream.map(fn {name, c} -> {name, Map.delete(c, :kind)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {name, component} ->
      component =
        Map.merge(component, %{
          name: to_string(name),
          module: Heroicons,
          fun_name: name
        })

      menu_button = ComponentRender.render(%{component | attrs: []})
      rest = Enum.find(component.attrs, &match?(%{name: :rest}, &1))

      attrs = [
        {"kind",
         %{
           name: :kind,
           type: :atom,
           value: nil,
           opts: [default: :outline, values: [:outline, :solid, :mini]],
           required: false,
           slot: nil,
           doc: nil
         }},
        {"rest", Map.put(rest, :value, class: "w-12")}
      ]

      Map.merge(component, %{
        attrs: attrs,
        render: &__MODULE__.render/1,
        menu_button: menu_button,
        preview_class: "inline-block",
        example_preview: nil
      })
    end)
  end

  defp handle_attrs(attrs) do
    Enum.reduce(attrs, [], fn
      {"kind", %{value: style}}, acc ->
        case style do
          nil -> acc
          :outline -> acc
          :solid -> [{"solid", %{name: style, value: true}} | acc]
          :mini -> [{"mini", %{name: style, value: true}} | acc]
        end

      item, acc ->
        [item | acc]
    end)
    |> Enum.reverse()
  end

  def render(component) do
    attrs = handle_attrs(component.attrs)
    ComponentRender.render(%{component | attrs: attrs})
  end
end
