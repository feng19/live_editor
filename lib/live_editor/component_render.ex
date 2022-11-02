defmodule LiveEditor.ComponentRender do
  @moduledoc false

  def render(component, env_or_opts \\ __ENV__) do
    slots = component.slots |> Stream.map(&elem(&1, 1)) |> Enum.filter(& &1[:value])
    attrs = component.attrs |> Stream.map(&elem(&1, 1)) |> Enum.filter(& &1[:value])

    attrs =
      Enum.reduce(attrs, [], fn
        %{type: :global, value: rest}, acc when is_list(rest) ->
          rest ++ acc

        %{name: k, value: v}, acc ->
          [{k, v} | acc]
      end)

    assigns = Map.get(component, :assigns, %{}) |> Map.put(:attrs, attrs)

    let =
      if let = component[:let] do
        ":let={#{let}}"
      else
        nil
      end


    {line, string} =
      if not Enum.empty?(slots) do
        {
          __ENV__.line + 2,
          """
          <#{component.module}.#{component.fun_name} #{let} {@attrs}>
            #{Stream.map(slots, & &1.value) |> Enum.join("\n")}
          </#{component.module}.#{component.fun_name}>
          """
        }
      else
        {
          __ENV__.line + 1,
          "<#{component.module}.#{component.fun_name} #{let} {@attrs}/>"
        }
      end

    quoted_code =
      EEx.compile_string(string,
        engine: Phoenix.LiveView.HTMLEngine,
        file: __ENV__.file,
        line: line,
        caller: __ENV__
      )

    {evaluated, _} = Code.eval_quoted(quoted_code, [assigns: assigns], env_or_opts)

    Phoenix.LiveView.Engine.live_to_iodata(evaluated)
  end
end
