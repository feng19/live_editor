defmodule LiveEditor.ComponentRender do
  @moduledoc false

  def env do
    import Phoenix.LiveView.Helpers, warn: false
    import Phoenix.Component, warn: false
    import Phoenix.Component.Declarative, warn: false
    require Phoenix.Template
    __ENV__
  end

  def render(component, env_or_opts \\ env()) do
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

    env_or_opts =
      if is_struct(env_or_opts, Macro.Env) do
        merge_component_module_to_env(component.module, env_or_opts)
      else
        env_or_opts
      end

    {evaluated, _} = Code.eval_quoted(quoted_code, [assigns: assigns], env_or_opts)
    Phoenix.LiveView.Engine.live_to_iodata(evaluated)
  end

  defp merge_component_module_to_env(module, env) do
    env
    |> Map.update!(:requires, &[module | &1])
    |> Map.update!(:functions, &[{module, module.__info__(:functions)} | &1])
  end
end
