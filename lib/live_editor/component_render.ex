defmodule LiveEditor.ComponentRender do
  @moduledoc false

  def env do
    import Phoenix.LiveView.Helpers, warn: false
    import Phoenix.Component, warn: false
    import Phoenix.Component.Declarative, warn: false
    require Phoenix.Template
    __ENV__
  end

  def component_code_string(component) do
    component |> component_code() |> elem(1)
  end

  def component_code(component) do
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
        slots = Enum.map(slots, & &1.value) |> List.flatten() |> Enum.join("\n")

        case component.module do
          :tag ->
            tag = component.name

            {
              __ENV__.line + 2,
              """
              <#{tag} #{let} {@attrs}>
                #{slots}
              </#{tag}>
              """
            }

          module ->
            module = inspect(module)
            fun_name = component.fun_name

            {
              __ENV__.line + 2,
              """
              <#{module}.#{fun_name} #{let} {@attrs}>
                #{slots}
              </#{module}.#{fun_name}>
              """
            }
        end
      else
        case component.module do
          :tag ->
            {
              __ENV__.line + 1,
              "<#{component.name} #{let} {@attrs} />"
            }

          module ->
            {
              __ENV__.line + 1,
              "<#{inspect(module)}.#{component.fun_name} #{let} {@attrs} />"
            }
        end
      end

    %{line: line, string: string, assigns: assigns}
  end

  def render(component, raw? \\ true, env_or_opts \\ env()) do
    %{line: line, string: string, assigns: assigns} = component_code(component)

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

    rendered =
      Code.eval_quoted(quoted_code, [assigns: assigns], env_or_opts)
      |> elem(0)
      |> Phoenix.LiveView.Engine.live_to_iodata()

    if raw? do
      rendered
      |> Phoenix.HTML.Safe.to_iodata()
      |> Phoenix.HTML.raw()
    else
      rendered
    end
  end

  defp merge_component_module_to_env(:tag, env), do: env

  defp merge_component_module_to_env(module, env) do
    env
    |> Map.update!(:requires, &[module | &1])
    |> Map.update!(:functions, &[{module, module.__info__(:functions)} | &1])
  end
end
