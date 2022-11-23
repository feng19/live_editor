defmodule LiveEditor.Parser do
  @moduledoc false

  alias LiveEditor.{CodeRender, Tokenizer}

  def parse(source) do
    newlines = :binary.matches(source, ["\r\n", "\n"])

    source
    |> Tokenizer.tokenize()
    |> Tokenizer.to_tree([], [], {source, newlines})
    |> IO.inspect(label: "tree")
    |> case do
      {:ok, tree} ->
        # tree: [{:tag_block, name, attrs, block, %{mode: mode}}]
        Stream.map(tree, fn
          {:text, _text, _} -> nil
          tag -> parse_tag(tag)
        end)
        |> Enum.reject(&is_nil/1)
        |> IO.inspect(label: "un tree")

      error ->
        error
    end
  end

  defp parse_tag({:tag_block, tag, attrs, blocks, _}) do
    base_tag(tag, attrs, blocks)
  end

  defp parse_tag({:tag_self_close, tag, attrs}) do
    base_tag(tag, attrs, [])
  end

  defp attrs_to_rest_value(attrs) do
    for {attr, value, _info} <- attrs do
      case value do
        {:string, v, _} -> {String.to_existing_atom(attr), v}
      end
    end
  end

  defp blocks_to_children([]), do: []

  defp blocks_to_children(blocks) do
    Stream.map(blocks, fn
      {:text, value, _} ->
        text = String.trim(value)

        if text != "" do
          %{type: :text, value: text}
        else
          nil
        end

      tag ->
        parse_tag(tag)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp base_tag(tag, attrs, blocks) do
    children = blocks_to_children(blocks)

    %{
      type: :base,
      module: :tag,
      fun_name: String.to_existing_atom(tag),
      name: tag,
      let: nil,
      assigns: %{},
      attrs: [
        {"rest",
         %{
           name: :rest,
           type: :global,
           value: attrs_to_rest_value(attrs),
           opts: [],
           required: false,
           slot: nil,
           doc: nil
         }}
      ],
      slots: [
        {"inner_block",
         %{
           name: :inner_block,
           value: nil,
           attrs: [],
           opts: [],
           required: false,
           doc: nil
         }}
      ],
      children: children
    }
  end

  def to_string(meta) do
    # IO.inspect(meta)

    Enum.map(meta, fn {_, c} ->
      with render when not is_nil(render) <- c[:code_render],
           true <- is_function(render, 1) do
        render.(c)
      else
        _ -> CodeRender.component_string(c)
      end
    end)
    |> Enum.join("\n")
    |> Phoenix.LiveView.HTMLFormatter.format([])
  end
end
