defmodule LiveEditor.UI.Heroicons do
  @moduledoc false

  def components(endpoint) do
    Heroicons.__components__()
    |> Stream.filter(&match?({_, %{kind: :def}}, &1))
    |> Enum.map(fn {name, component} ->
      rest = Enum.find(component.attrs, &match?(%{name: :rest}, &1))

      attrs = [
        %{
          name: :kind,
          type: :atom,
          opts: [default: :outline, values: [:outline, :solid, :mini]],
          required: false,
          slot: nil,
          doc: nil
        },
        rest
      ]

      preview = LiveEditor.UI.Helper.render_component(endpoint, {Heroicons, name}, [])

      Map.merge(component, %{
        name: to_string(name),
        module: Heroicons,
        fun_name: name,
        attrs: attrs,
        assigns: [class: "w-12"],
        assigns_handler: &__MODULE__.handle_assigns/1,
        # render: &__MODULE__.render/3,
        preview: preview
      })
    end)
  end

  def handle_assigns(assigns) do
    Enum.reduce(assigns, [], fn
      {:kind, style}, acc ->
        case style do
          :outline -> acc
          :solid -> [{:solid, true} | acc]
          :mini -> [{:mini, true} | acc]
        end

      item, acc ->
        [item | acc]
    end)
    |> Enum.reverse()
  end

#  def render(component, assigns, endpoint) do
#    LiveEditor.UI.Helper.render_component(
#      endpoint,
#      {component.module, component.fun_name},
#      assigns
#    )
#  end
end
