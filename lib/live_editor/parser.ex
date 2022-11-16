defmodule LiveEditor.Parser do
  @moduledoc false

  alias LiveEditor.{CodeRender, Tokenizer}

  def parse(source) do
    newlines = :binary.matches(source, ["\r\n", "\n"])

    source
    |> Tokenizer.tokenize()
    |> Tokenizer.to_tree([], [], {source, newlines})
    |> Enum.map(fn
      {:tag_block, tag, attrs, children} ->
        :todo
    end)
  end

  def to_string(meta) do
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
